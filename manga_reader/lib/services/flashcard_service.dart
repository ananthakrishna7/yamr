import 'package:flutter/foundation.dart';
import 'package:manga_reader/models/dictionary_entry.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class FlashcardService extends ChangeNotifier {
  Database? _db;
  List<DictionaryEntry> _flashcards = [];
  bool _isLoading = true;

  List<DictionaryEntry> get flashcards => _flashcards;
  bool get isLoading => _isLoading;

  FlashcardService() {
    _initDb();
  }

  Future<void> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flashcards.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE flashcards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            term TEXT,
            reading TEXT,
            definitions TEXT
          )
        ''');
      },
    );
    await _loadCards();
  }

  Future<void> _loadCards() async {
    if (_db == null) return;

    _isLoading = true;
    notifyListeners();

    final List<Map<String, dynamic>> maps = await _db!.query('flashcards');

    _flashcards = List.generate(maps.length, (i) {
      return DictionaryEntry(
        term: maps[i]['term'],
        reading: maps[i]['reading'],
        definitions: (maps[i]['definitions'] as String).split('|'),
      );
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCard(DictionaryEntry entry) async {
    if (_db == null) return;

    await _db!.insert(
      'flashcards',
      {
        'term': entry.term,
        'reading': entry.reading,
        'definitions': entry.definitions.join('|'),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _loadCards();
  }
}
