import 'package:flutter/material.dart';
import 'package:manga_reader/models/manga_page.dart';

class OverlayLayer extends StatelessWidget {
  final List<OcrBlock> blocks;
  final Function(String) onTextTap;
  final bool debugMode;

  const OverlayLayer({
    super.key,
    required this.blocks,
    required this.onTextTap,
    this.debugMode = false,
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
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: debugMode ? Colors.red : Colors.white.withOpacity(0.5),
                  width: debugMode ? 2 : 1
                ),
              ),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  block.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 2.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
