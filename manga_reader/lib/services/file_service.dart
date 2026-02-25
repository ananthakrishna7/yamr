import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:manga_reader/models/manga_volume.dart';
import 'package:manga_reader/models/manga_series.dart';

class FileService extends ChangeNotifier {
  List<MangaSeries> _seriesLibrary = [];
  String? _libraryPath;
  bool _isLoading = false;

  List<MangaSeries> get seriesLibrary => _seriesLibrary;
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

    _seriesLibrary = [];
    final dir = Directory(_libraryPath!);

    if (await dir.exists()) {
      try {
        final List<FileSystemEntity> entities = dir.listSync();
        // Each entity in Root is potentially a Series
        for (var entity in entities) {
          if (entity is Directory) {
            if (p.basename(entity.path).startsWith('.')) continue;

            final series = await _scanSeries(entity);
            if (series != null) {
              _seriesLibrary.add(series);
            }
          }
        }

        // Sort library by title
        _seriesLibrary.sort((a, b) => a.title.compareTo(b.title));
      } catch (e) {
        debugPrint("Error scanning library: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<MangaSeries?> _scanSeries(Directory seriesDir) async {
    try {
      final List<MangaVolume> volumes = [];
      final List<FileSystemEntity> entities = seriesDir.listSync();

      // Check if this directory ITSELF is a volume (loose volume in root?)
      // But typically a Series contains Chapter folders.
      // So let's look for subdirectories.
      for (var entity in entities) {
        if (entity is Directory) {
           if (p.basename(entity.path).startsWith('.')) continue;

           // Check if this subdirectory is a Volume (contains images)
           final vol = await _scanVolume(entity);
           if (vol != null) {
             volumes.add(vol);
           }
        }
      }

      // If we found volumes, it's a series.
      if (volumes.isNotEmpty) {
        volumes.sort((a, b) => a.title.compareTo(b.title));
        return MangaSeries(
          path: seriesDir.path,
          title: p.basename(seriesDir.path),
          coverPath: volumes.first.coverPath, // Use cover of first volume
          volumes: volumes,
        );
      }

      // Edge case: Maybe the seriesDir itself contains images (Single volume series?)
      // If so, treat it as a Series with 1 Volume.
      final vol = await _scanVolume(seriesDir);
      if (vol != null) {
         return MangaSeries(
          path: seriesDir.path,
          title: p.basename(seriesDir.path),
          coverPath: vol.coverPath,
          volumes: [vol],
        );
      }

    } catch (e) {
      debugPrint("Error scanning series ${seriesDir.path}: $e");
    }
    return null;
  }

  Future<MangaVolume?> _scanVolume(Directory volDir) async {
    try {
      final List<FileSystemEntity> entities = volDir.listSync();
      // Check for images
      final images = entities.where((e) => e is File && _isImageFile(e.path)).toList();

      if (images.isNotEmpty) {
        images.sort((a, b) => a.path.compareTo(b.path));
        return MangaVolume(
          path: volDir.path,
          title: p.basename(volDir.path),
          coverPath: images.first.path,
        );
      }
    } catch (e) {
       debugPrint("Error scanning volume ${volDir.path}: $e");
    }
    return null;
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }
}
