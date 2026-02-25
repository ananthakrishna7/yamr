import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/ui/theme.dart';
import 'package:manga_reader/ui/home_screen.dart';
import 'package:manga_reader/services/file_service.dart';
import 'package:manga_reader/services/dictionary_service.dart';
import 'package:manga_reader/services/flashcard_service.dart';
import 'package:manga_reader/services/anki_service.dart';
import 'package:manga_reader/services/gemini_service.dart';
import 'package:manga_reader/services/settings_service.dart';

void main() {
  runApp(const MangaReaderApp());
}

class MangaReaderApp extends StatelessWidget {
  const MangaReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileService()),
        ChangeNotifierProvider(create: (_) => DictionaryService()),
        ChangeNotifierProvider(create: (_) => FlashcardService()),
        ChangeNotifierProvider(create: (_) => AnkiService()),
        ChangeNotifierProvider(create: (_) => GeminiService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: MaterialApp(
        title: 'Manga Reader',
        theme: CatppuccinTheme.themeData,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
