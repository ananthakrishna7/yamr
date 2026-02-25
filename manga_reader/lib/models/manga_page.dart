import 'dart:ui';

class OcrBlock {
  final String text;
  final Rect box;
  final List<String> lines;

  OcrBlock({
    required this.text,
    required this.box,
    required this.lines,
  });
}

class MangaPage {
  final String imagePath;
  final List<OcrBlock> blocks;
  final Size imageSize;

  MangaPage({
    required this.imagePath,
    required this.blocks,
    this.imageSize = Size.zero,
  });
}
