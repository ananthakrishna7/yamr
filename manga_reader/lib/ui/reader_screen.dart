import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/models/manga_volume.dart';
import 'package:manga_reader/models/manga_page.dart';
import 'package:manga_reader/services/settings_service.dart';
import 'package:manga_reader/utils/mokuro_parser.dart';
import 'package:manga_reader/ui/widgets/overlay_layer.dart';
import 'package:manga_reader/ui/widgets/dictionary_popup.dart';
import 'package:path/path.dart' as p;

class ReaderScreen extends StatefulWidget {
  final MangaVolume manga;

  const ReaderScreen({super.key, required this.manga});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String> _imagePaths = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  final Map<int, MangaPage> _pageCache = {};

  @override
  void initState() {
    super.initState();
    // Check settings for immersive mode
    // We need to wait for frame to access provider safely if listening, but context.read is fine here.
    // However, initState happens before the widget is fully in the tree for some provider checks,
    // but context.read is generally allowed if we don't listen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsService>();
      if (settings.immersiveMode) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });

    _loadImages();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadImages() async {
    final dir = Directory(widget.manga.path);
    if (await dir.exists()) {
      final entities = dir.listSync();
      _imagePaths = entities
          .where((e) => e is File && _isImageFile(e.path))
          .map((e) => e.path)
          .toList();
      _imagePaths.sort((a, b) => a.compareTo(b));
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }

  Future<MangaPage> _getPage(int index) async {
    if (_pageCache.containsKey(index)) return _pageCache[index]!;
    final path = _imagePaths[index];
    final page = await MokuroParser.parse(path);
    _pageCache[index] = page;
    return page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    return PhotoViewGalleryPageOptions.customChild(
                      child: FutureBuilder<MangaPage>(
                        future: _getPage(index),
                        builder: (context, snapshot) {
                          final image = Image.file(File(_imagePaths[index]));

                          if (!snapshot.hasData) {
                            return Center(child: image);
                          }

                          final page = snapshot.data!;

                          return Center(
                            child: Stack(
                              children: [
                                image,
                                if (page.blocks.isNotEmpty)
                                  Consumer<SettingsService>(
                                    builder: (context, settings, child) {
                                      if (!settings.showOverlay) return const SizedBox.shrink();
                                      return Positioned.fill(
                                        child: OverlayLayer(
                                          blocks: page.blocks,
                                          onTextTap: (text) {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (context) => DictionaryPopup(term: text),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                      basePosition: Alignment.center,
                      heroAttributes: PhotoViewHeroAttributes(tag: _imagePaths[index]),
                    );
                  },
                  itemCount: _imagePaths.length,
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                      ),
                    ),
                  ),
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
                // Only show controls if not immersive? Or show on tap?
                // For now, keep them visible.
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Text(
                    "${_currentIndex + 1} / ${_imagePaths.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
