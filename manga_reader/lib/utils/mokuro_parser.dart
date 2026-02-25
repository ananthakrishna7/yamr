import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:manga_reader/models/manga_page.dart';
import 'package:path/path.dart' as p;

class MokuroParser {
  static Future<MangaPage> parse(String imagePath) async {
    final dir = File(imagePath).parent.path;
    final filename = p.basename(imagePath);
    final jsonName = '${p.basenameWithoutExtension(filename)}.json';

    // Check typical locations
    // 1. _ocr subdirectory
    String jsonPath = p.join(dir, '_ocr', jsonName);

    // 2. Same directory
    if (!await File(jsonPath).exists()) {
      jsonPath = p.join(dir, jsonName);
    }

    if (await File(jsonPath).exists()) {
      try {
        final content = await File(jsonPath).readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final blocks = <OcrBlock>[];
        if (data.containsKey('blocks')) {
           for (var b in data['blocks']) {
             final box = b['box']; // [x, y, w, h]
             final lines = (b['lines'] as List).map((e) => e.toString()).toList();
             final text = lines.join(''); // Join lines for lookup

             // Review feedback: Mokuro box is typically [min_x, min_y, max_x, max_y]
             blocks.add(OcrBlock(
               text: text,
               box: Rect.fromLTRB(
                 (box[0] as num).toDouble(),
                 (box[1] as num).toDouble(),
                 (box[2] as num).toDouble(),
                 (box[3] as num).toDouble(),
               ),
               lines: lines,
             ));
           }
        }

        double width = 0;
        double height = 0;
        if (data.containsKey('img_width')) width = (data['img_width'] as num).toDouble();
        if (data.containsKey('img_height')) height = (data['img_height'] as num).toDouble();

        return MangaPage(
          imagePath: imagePath,
          blocks: blocks,
          imageSize: Size(width, height),
        );

      } catch (e) {
        debugPrint('Error parsing JSON for $imagePath: $e');
      }
    }

    return MangaPage(imagePath: imagePath, blocks: []);
  }
}
