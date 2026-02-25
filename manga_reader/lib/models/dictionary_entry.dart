class DictionaryEntry {
  final String term;
  final String reading;
  final List<String> definitions;

  DictionaryEntry({
    required this.term,
    required this.reading,
    required this.definitions,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      term: json['term'] ?? '',
      reading: json['reading'] ?? '',
      definitions: List<String>.from(json['definitions'] ?? []),
    );
  }
}
