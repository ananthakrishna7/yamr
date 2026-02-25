import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:manga_reader/models/dictionary_entry.dart';

class AnkiService extends ChangeNotifier {

  Future<void> addCard(DictionaryEntry entry) async {
    // Using Intent to open AnkiDroid's Add Card screen
    final intent = AndroidIntent(
      action: 'com.ichi2.anki.DO_ADD_CARD',
      arguments: <String, dynamic>{
        'n': 'Basic', // Default Model Name
        'd': 'Default', // Default Deck Name
        'f1': entry.term, // Front
        'f2': '${entry.reading}\n\n${entry.definitions.join(', ')}', // Back
        'tags': 'manga_reader',
      },
    );

    try {
        await intent.launch();
    } catch (e) {
        debugPrint("Error launching Anki intent: $e");
    }
  }
}
