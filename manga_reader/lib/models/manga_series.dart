import 'package:manga_reader/models/manga_volume.dart';

class MangaSeries {
  final String path;
  final String title;
  final String coverPath;
  final List<MangaVolume> volumes;

  MangaSeries({
    required this.path,
    required this.title,
    required this.coverPath,
    required this.volumes,
  });
}
