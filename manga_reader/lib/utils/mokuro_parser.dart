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

    debugPrint("[MokuroParser] Parsing request for image: $filename in $dirPath");

    // 1. Check if we already loaded data for this chapter
    if (!_chapterCache.containsKey(dirPath)) {
      debugPrint("[MokuroParser] Chapter data not cached for $dirPath. Loading...");
      await _loadChapterData(dirPath);
    }

    final chapterData = _chapterCache[dirPath];
    if (chapterData != null) {
      debugPrint("[MokuroParser] Looking for keys matching '$filename' or '$filenameNoExt' in chapter data (size: ${chapterData.length})");

      // Try exact match
      if (chapterData.containsKey(filename)) {
        debugPrint("[MokuroParser] Found exact match for '$filename'");
        return MangaPage(imagePath: imagePath, blocks: chapterData[filename]!);
      }
      if (chapterData.containsKey(filenameNoExt)) {
         debugPrint("[MokuroParser] Found match for '$filenameNoExt'");
         return MangaPage(imagePath: imagePath, blocks: chapterData[filenameNoExt]!);
      }

      // Try without leading zeros or other loose matching
      // e.g. "001.jpg" -> "1.jpg" or "1"
      try {
        final num = int.tryParse(filenameNoExt);
        if (num != null) {
           final numStr = num.toString();
           if (chapterData.containsKey(numStr)) {
              debugPrint("[MokuroParser] Found numeric match '$numStr' for '$filenameNoExt'");
              return MangaPage(imagePath: imagePath, blocks: chapterData[numStr]!);
           }
           // Try numStr + extension
           final ext = p.extension(filename);
           if (chapterData.containsKey('$numStr$ext')) {
              debugPrint("[MokuroParser] Found numeric match '$numStr$ext' for '$filename'");
              return MangaPage(imagePath: imagePath, blocks: chapterData['$numStr$ext']!);
           }
        }
      } catch (e) {
        // ignore
      }

      // Also check for json extension keys
      final jsonName = '$filenameNoExt.json';
      if (chapterData.containsKey(jsonName)) {
        debugPrint("[MokuroParser] Found match for '$jsonName'");
        return MangaPage(imagePath: imagePath, blocks: chapterData[jsonName]!);
      }

      debugPrint("[MokuroParser] No matching key found in chapter data.");
    } else {
       debugPrint("[MokuroParser] No chapter data loaded.");
    }

    // Fallback: Check for individual JSON file (legacy behavior)
    final jsonName = '$filenameNoExt.json';
    // Check _ocr subdirectory
    String jsonPath = p.join(dirPath, '_ocr', jsonName);
    if (!await File(jsonPath).exists()) {
      jsonPath = p.join(dirPath, jsonName);
    }

    if (await File(jsonPath).exists()) {
      debugPrint("[MokuroParser] Found legacy JSON at $jsonPath");
      try {
        final content = await File(jsonPath).readAsString();
        final blocks = _parseBlocks(jsonDecode(content));
        return MangaPage(imagePath: imagePath, blocks: blocks);
      } catch (e) {
        debugPrint('Error parsing legacy JSON for $imagePath: $e');
      }
    } else {
        debugPrint("[MokuroParser] Legacy JSON not found at $jsonPath");
    }

    return MangaPage(imagePath: imagePath, blocks: []);
  }

  static Future<void> _loadChapterData(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    try {
      final entities = dir.listSync();
      // Look for a .mokuro file
      // Could be 'mokuro.mokuro' or just 'something.mokuro'
      final mokuroFiles = entities.where(
        (e) => e is File && p.extension(e.path).toLowerCase() == '.mokuro',
      ).toList();

      if (mokuroFiles.isNotEmpty) {
        // Prioritize a file named same as directory if multiple exist, otherwise pick first
        File mokuroFile = mokuroFiles.first as File;
        debugPrint("[MokuroParser] Found .mokuro file: ${mokuroFile.path}");
        await _parseMokuroFile(mokuroFile, dirPath);
        return;
      } else {
        debugPrint("[MokuroParser] No .mokuro file found in $dirPath");
      }
    } catch (e) {
      debugPrint("Error loading chapter data for $dirPath: $e");
    }
  }

  static Future<void> _parseMokuroFile(File file, String dirPath) async {
    final Map<String, List<OcrBlock>> chapterData = {};

    try {
      final bytes = await file.readAsBytes();
      bool processed = false;

      // Try to decode as ZIP
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        debugPrint("[MokuroParser] Decoded .mokuro as ZIP with ${archive.length} files");
        processed = true;
        for (final file in archive) {
          if (file.isFile) {
             final filename = p.basename(file.name);
             // Skip hidden files or useless ones
             if (filename.startsWith('.') || filename == 'version.json' || filename == 'index.json') continue;

             if (p.extension(filename).toLowerCase() == '.json') {
               try {
                 final content = utf8.decode(file.content as List<int>);
                 final data = jsonDecode(content);
                 final blocks = _parseBlocks(data);

                 // Determine key: usually the image filename corresponds to the json filename
                 // e.g. _ocr/001.json -> data for 001.jpg
                 // We store by filename without extension as primary key
                 final key = p.basenameWithoutExtension(filename); // "001"

                 // Store variants
                 chapterData[key] = blocks;
                 chapterData[filename] = blocks; // "001.json"
                 chapterData['$key.jpg'] = blocks;
                 chapterData['$key.png'] = blocks;
                 chapterData['$key.webp'] = blocks;

                 // Handle numeric variants
                 final num = int.tryParse(key);
                 if (num != null) {
                    chapterData[num.toString()] = blocks;
                 }
               } catch (e) {
                 debugPrint("Error parsing JSON inside mokuro zip ($filename): $e");
               }
             }
          }
        }
      } catch (e) {
        debugPrint("[MokuroParser] Not a valid ZIP file: $e");
      }

      // If not ZIP, try single JSON
      if (!processed) {
        try {
           final content = utf8.decode(bytes);
           final data = jsonDecode(content);
           debugPrint("[MokuroParser] Decoded .mokuro as single JSON");

           // If it's a single JSON, it might be a map of "pages" or similar
           // Structure 1: { "pages": [ { "img_path": "001.jpg", "blocks": ... } ] }
           if (data is Map && data.containsKey('pages')) {
              int pageCount = 0;
              for (var page in (data['pages'] as List)) {
                 if (page is Map) {
                    // Try 'img_path' or check if key is the filename
                    String? imgPath = page['img_path'] as String?;
                    if (imgPath != null) {
                       final key = p.basename(imgPath);
                       final blocks = _parseBlocks(page);
                       chapterData[key] = blocks;
                       chapterData[p.basenameWithoutExtension(key)] = blocks;
                       pageCount++;
                    }
                 }
              }
              debugPrint("[MokuroParser] Parsed $pageCount pages from 'pages' array");
           }
           // Structure 2: Map of filename -> data { "001.jpg": { "blocks": ... }, ... }
           else if (data is Map) {
             data.forEach((key, value) {
                if (value is Map && (value.containsKey('blocks') || value.containsKey('lines'))) {
                   final blocks = _parseBlocks(value);
                   chapterData[key.toString()] = blocks;
                   chapterData[p.basenameWithoutExtension(key.toString())] = blocks;
                }
             });
             debugPrint("[MokuroParser] Parsed ${chapterData.length} entries from root map");
           }
        } catch (jsonErr) {
           debugPrint("Error parsing mokuro file as JSON: $jsonErr");
        }
      }

      if (chapterData.isNotEmpty) {
        _chapterCache[dirPath] = chapterData;
        debugPrint("Loaded total ${chapterData.length} keys (including aliases) from ${file.path}");
      } else {
         debugPrint("[MokuroParser] Warning: No data extracted from .mokuro file.");
      }

    } catch (e) {
      debugPrint("Error reading mokuro file: $e");
    }
  }

  static List<OcrBlock> _parseBlocks(Map<dynamic, dynamic> data) {
    final blocks = <OcrBlock>[];
    if (data.containsKey('blocks')) {
       for (var b in data['blocks']) {
         try {
             final box = b['box']; // [x, y, w, h] or [min_x, min_y, max_x, max_y]
             // Ensure box is List<num>
             if (box is List && box.length >= 4) {
                 final x = (box[0] as num).toDouble();
                 final y = (box[1] as num).toDouble();
                 final w = (box[2] as num).toDouble(); // Could be width or max_x
                 final h = (box[3] as num).toDouble(); // Could be height or max_y

                 // Mokuro typically uses [min_x, min_y, max_x, max_y]
                 // But Flutter Rect.fromLTRB takes (left, top, right, bottom)
                 // If w < x, it's definitely not max_x (unless coordinate system is weird)
                 // Assuming [min_x, min_y, max_x, max_y] based on typical OCR output

                 final lines = (b['lines'] as List).map((e) => e.toString()).toList();
                 final text = lines.join('');

                 blocks.add(OcrBlock(
                   text: text,
                   box: Rect.fromLTRB(x, y, w, h),
                   lines: lines,
                 ));
             }
         } catch (e) {
             debugPrint("Error parsing block: $e");
         }
       }
    }
    return blocks;
  }
}
