import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/services/file_service.dart';
import 'package:manga_reader/ui/theme.dart';
import 'package:manga_reader/ui/series_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              context.read<FileService>().pickDirectory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FileService>().scanLibrary();
            },
          ),
        ],
      ),
      body: Consumer<FileService>(
        builder: (context, fileService, child) {
          if (fileService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (fileService.libraryPath == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books, size: 64, color: CatppuccinTheme.overlay0),
                  const SizedBox(height: 16),
                  const Text('No library selected'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => fileService.pickDirectory(),
                    child: const Text('Select Manga Folder'),
                  ),
                ],
              ),
            );
          }

          if (fileService.seriesLibrary.isEmpty) {
            return const Center(child: Text('No manga found in this folder'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 columns for phones
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: fileService.seriesLibrary.length,
            itemBuilder: (context, index) {
              final series = fileService.seriesLibrary[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeriesScreen(series: series),
                    ),
                  );
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.file(
                          File(series.coverPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              series.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${series.volumes.length} Volumes',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
