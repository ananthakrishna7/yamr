import 'package:flutter/material.dart';
import 'package:manga_reader/models/manga_page.dart';

class OverlayLayer extends StatelessWidget {
  final List<OcrBlock> blocks;
  final Function(String) onTextTap;

  const OverlayLayer({
    super.key,
    required this.blocks,
    required this.onTextTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: blocks.map((block) {
        return Positioned(
          left: block.box.left,
          top: block.box.top,
          width: block.box.width,
          height: block.box.height,
          child: GestureDetector(
            onTap: () => onTextTap(block.text),
            child: Container(
              color: Colors.transparent, // Invisible but clickable
            ),
          ),
        );
      }).toList(),
    );
  }
}
