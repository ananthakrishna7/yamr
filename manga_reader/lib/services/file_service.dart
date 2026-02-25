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
        await _scanRecursive(dir);
        // Sort library by title
        _mangaLibrary.sort((a, b) => a.title.compareTo(b.title));
      } catch (e) {
        debugPrint("Error scanning library: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _scanRecursive(Directory dir) async {
    try {
      final List<FileSystemEntity> entities = dir.listSync();

      // Check if this directory contains images
      final images = entities.where((e) => e is File && _isImageFile(e.path)).toList();

      if (images.isNotEmpty) {
        images.sort((a, b) => a.path.compareTo(b.path));
        _mangaLibrary.add(MangaVolume(
          path: dir.path,
          title: p.basename(dir.path),
          coverPath: images.first.path,
        ));
      }

      for (var entity in entities) {
        if (entity is Directory) {
          if (p.basename(entity.path).startsWith('.')) continue;
          await _scanRecursive(entity);
        }
      }
    } catch (e) {
      debugPrint("Error scanning subdir ${dir.path}: $e");
    }
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }
}
