import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:manga_reader/models/manga_volume.dart';

class FileService extends ChangeNotifier {
  List<MangaVolume> _mangaLibrary = [];
  String? _libraryPath;
  bool _isLoading = false;

  List<MangaVolume> get mangaLibrary => _mangaLibrary;
  String? get libraryPath => _libraryPath;
  bool get isLoading => _isLoading;

  FileService() {
    _loadLibraryPath();
  }

  Future<void> _loadLibraryPath() async {
    final prefs = await SharedPreferences.getInstance();
    _libraryPath = prefs.getString('library_path');
    if (_libraryPath != null) {
      await scanLibrary();
    }
  }

  Future<void> pickDirectory() async {
    // Request storage permissions
    // On Android 11+ (API 30+), Manage External Storage is needed for broad access
    // On older versions, Storage permission is enough.

    bool permissionGranted = false;
    if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.status;
        if (status.isGranted) {
            permissionGranted = true;
        } else {
            final result = await Permission.manageExternalStorage.request();
            if (result.isGranted) {
                permissionGranted = true;
            } else {
                 // Fallback for older Android or if manage storage is not available/needed
                 if (await Permission.storage.request().isGranted) {
                     permissionGranted = true;
                 }
            }
        }
    } else {
        permissionGranted = true;
    }

    if (permissionGranted) {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        _libraryPath = selectedDirectory;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('library_path', _libraryPath!);
        await scanLibrary();
      }
    } else {
        debugPrint("Permission denied");
    }
  }

  Future<void> scanLibrary() async {
    if (_libraryPath == null) return;

    _isLoading = true;
    notifyListeners();

    _mangaLibrary = [];
    final dir = Directory(_libraryPath!);

    if (await dir.exists()) {
      try {
        final List<FileSystemEntity> entities = dir.listSync();

        for (var entity in entities) {
          if (entity is Directory) {
            // Check if directory contains images
            // A simple heuristic: check for at least one image file
            try {
                final images = entity.listSync().where((e) {
                  return e is File && _isImageFile(e.path);
                }).toList();

                if (images.isNotEmpty) {
                  // Sort to find the first image as cover
                  images.sort((a, b) => a.path.compareTo(b.path));

                  _mangaLibrary.add(MangaVolume(
                    path: entity.path,
                    title: p.basename(entity.path),
                    coverPath: images.first.path,
                  ));
                }
            } catch (e) {
                debugPrint("Error reading subdir: $e");
            }
          }
        }
      } catch (e) {
        debugPrint("Error scanning library: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }
}
