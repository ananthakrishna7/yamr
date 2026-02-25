import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:manga_reader/models/dictionary_entry.dart';

class DictionaryService extends ChangeNotifier {
  List<DictionaryEntry> _entries = [];
  bool _isLoaded = false;

  DictionaryService() {
    _loadSampleDictionary();
  }

  Future<void> _loadSampleDictionary() async {
    try {
      final jsonString = await rootBundle.loadString('assets/dict_sample.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _entries = jsonList.map((e) => DictionaryEntry.fromJson(e)).toList();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading dictionary: $e");
    }
  }

  Future<List<DictionaryEntry>> lookup(String query) async {
    if (!_isLoaded) {
      await _loadSampleDictionary();
    }

    return _entries.where((e) {
      return query.contains(e.term) || e.term == query;
    }).toList();
  }
}
