import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:manga_reader/models/manga_page.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

class MokuroParser {
  // Cache for chapter data: directory path -> map of filename -> OCR blocks
  static final Map<String, Map<String, List<OcrBlock>>> _chapterCache = {};

  static Future<MangaPage> parse(String imagePath) async {
    final file = File(imagePath);
    final dirPath = file.parent.path;
    final filename = p.basename(imagePath);
    final filenameNoExt = p.basenameWithoutExtension(filename);

    // 1. Check if we already loaded data for this chapter
    if (!_chapterCache.containsKey(dirPath)) {
      await _loadChapterData(dirPath);
    }

    final chapterData = _chapterCache[dirPath];
    if (chapterData != null) {
      // Try to find blocks for this image
      // Keys might be full filename or filename without extension
      if (chapterData.containsKey(filename)) {
        return MangaPage(imagePath: imagePath, blocks: chapterData[filename]!);
      }
      if (chapterData.containsKey(filenameNoExt)) {
         return MangaPage(imagePath: imagePath, blocks: chapterData[filenameNoExt]!);
      }
      // Also check for json extension keys
      final jsonName = '$filenameNoExt.json';
      if (chapterData.containsKey(jsonName)) {
        return MangaPage(imagePath: imagePath, blocks: chapterData[jsonName]!);
      }
    }

    // Fallback: Check for individual JSON file (legacy behavior)
    final jsonName = '$filenameNoExt.json';
    // Check _ocr subdirectory
    String jsonPath = p.join(dirPath, '_ocr', jsonName);
    if (!await File(jsonPath).exists()) {
      jsonPath = p.join(dirPath, jsonName);
    }

    if (await File(jsonPath).exists()) {
      try {
        final content = await File(jsonPath).readAsString();
        final blocks = _parseBlocks(jsonDecode(content));
        return MangaPage(imagePath: imagePath, blocks: blocks);
      } catch (e) {
        debugPrint('Error parsing legacy JSON for $imagePath: $e');
      }
    }

    return MangaPage(imagePath: imagePath, blocks: []);
  }

  static Future<void> _loadChapterData(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    try {
      final entities = dir.listSync();
      // Look for a .mokuro file
      final mokuroFile = entities.firstWhere(
        (e) => e is File && p.extension(e.path).toLowerCase() == '.mokuro',
        orElse: () => File(''),
      );

      if (mokuroFile.path.isNotEmpty) {
        await _parseMokuroFile(mokuroFile as File, dirPath);
        return;
      }

      // If no .mokuro, check for _ocr directory and load all jsons there?
      // For now, we rely on per-file fallback if no .mokuro file is found.
    } catch (e) {
      debugPrint("Error loading chapter data for $dirPath: $e");
    }
  }

  static Future<void> _parseMokuroFile(File file, String dirPath) async {
    final Map<String, List<OcrBlock>> chapterData = {};

    try {
      final bytes = await file.readAsBytes();

      // Try to decode as ZIP
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.isFile) {
             final filename = p.basename(file.name);
             if (p.extension(filename).toLowerCase() == '.json') {
               try {
                 final content = utf8.decode(file.content as List<int>);
                 final data = jsonDecode(content);
                 // Determine key: usually the image filename corresponds to the json filename
                 // e.g. _ocr/001.json -> data for 001.jpg
                 // We store by json filename (e.g. "001.json") or "001"
                 final key = p.basenameWithoutExtension(filename); // "001"
                 chapterData[key] = _parseBlocks(data);
                 chapterData['$key.jpg'] = chapterData[key]!; // Alias
                 chapterData['$key.png'] = chapterData[key]!; // Alias
                 chapterData['$key.webp'] = chapterData[key]!; // Alias
               } catch (e) {
                 debugPrint("Error parsing JSON inside mokuro zip: $e");
               }
             }
          }
        }
      } catch (e) {
        // Not a zip? Maybe a single JSON file?
        try {
           final content = utf8.decode(bytes);
           final data = jsonDecode(content);
           // If it's a single JSON, it might be a map of "pages" or similar
           if (data is Map && data.containsKey('pages')) {
              // Iterate pages
              // Structure assumption: { "pages": [ { "img_path": "...", "blocks": ... } ] }
              for (var page in data['pages']) {
                 if (page is Map) {
                    final imgPath = page['img_path'] as String?;
                    if (imgPath != null) {
                       final key = p.basename(imgPath);
                       chapterData[key] = _parseBlocks(page);
                       chapterData[p.basenameWithoutExtension(key)] = chapterData[key]!;
                    }
                 }
              }
           } else if (data is Map) {
             // Maybe map of filename -> data?
             data.forEach((key, value) {
                if (value is Map) {
                   chapterData[key.toString()] = _parseBlocks(value);
                }
             });
           }
        } catch (jsonErr) {
           debugPrint("Error parsing mokuro file as JSON: $jsonErr");
        }
      }

      if (chapterData.isNotEmpty) {
        _chapterCache[dirPath] = chapterData;
        debugPrint("Loaded ${chapterData.length} pages from ${file.path}");
      }

    } catch (e) {
      debugPrint("Error reading mokuro file: $e");
    }
  }

  static List<OcrBlock> _parseBlocks(Map<dynamic, dynamic> data) {
    final blocks = <OcrBlock>[];
    if (data.containsKey('blocks')) {
       for (var b in data['blocks']) {
         final box = b['box']; // [x, y, w, h] or [min_x, min_y, max_x, max_y]
         final lines = (b['lines'] as List).map((e) => e.toString()).toList();
         final text = lines.join('');

         // Mokuro box is typically [min_x, min_y, max_x, max_y]
         // Flutter Rect.fromLTRB takes (left, top, right, bottom)
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
    return blocks;
  }
}
