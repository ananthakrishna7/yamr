import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/services/flashcard_service.dart';

class FlashcardScreen extends StatelessWidget {
  const FlashcardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: Consumer<FlashcardService>(
        builder: (context, flashcardService, child) {
          if (flashcardService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (flashcardService.flashcards.isEmpty) {
            return const Center(child: Text('No flashcards yet'));
          }

          return ListView.builder(
            itemCount: flashcardService.flashcards.length,
            itemBuilder: (context, index) {
              final card = flashcardService.flashcards[index];
              return ListTile(
                title: Text(card.term),
                subtitle: Text(card.reading),
                trailing: Text(card.definitions.first),
                // Add functionality later
              );
            },
          );
        },
      ),
    );
  }
}
