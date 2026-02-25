import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/services/dictionary_service.dart';
import 'package:manga_reader/models/dictionary_entry.dart';
import 'package:manga_reader/services/flashcard_service.dart';
import 'package:manga_reader/services/anki_service.dart';
import 'package:manga_reader/services/gemini_service.dart';

class DictionaryPopup extends StatefulWidget {
  final String term;

  const DictionaryPopup({super.key, required this.term});

  @override
  State<DictionaryPopup> createState() => _DictionaryPopupState();
}

class _DictionaryPopupState extends State<DictionaryPopup> {
  List<DictionaryEntry>? _results;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    final results = await context.read<DictionaryService>().lookup(widget.term);
    if (mounted) {
      setState(() {
        _results = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_results == null) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_results!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No definition found for "${widget.term}"', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text("Try selecting a smaller part of the text."),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results!.length,
              itemBuilder: (context, index) {
                final entry = _results![index];
                return ListTile(
                  title: Text('${entry.term} (${entry.reading})'),
                  subtitle: Text(entry.definitions.join(', ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.star_border),
                        onPressed: () {
                           context.read<FlashcardService>().addCard(entry);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Flashcards")));
                        },
                      ),
                       IconButton(
                        icon: const Icon(Icons.add_to_photos), // Anki icon proxy
                        onPressed: () {
                           context.read<AnkiService>().addCard(entry);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent to Anki")));
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          TextButton.icon(
            icon: const Icon(Icons.psychology),
            label: const Text("Explain with AI"),
            onPressed: () async {
              final explanation = await context.read<GeminiService>().explain(widget.term);
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("AI Explanation"),
                  content: SingleChildScrollView(child: Text(explanation)),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
