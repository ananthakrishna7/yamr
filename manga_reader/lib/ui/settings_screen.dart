import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_reader/services/gemini_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid listening during build if needed,
    // but reading is fine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<GeminiService>();
      if (service.apiKey != null) {
        _apiKeyController.text = service.apiKey!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<GeminiService>().setApiKey(value);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Get your API key from Google AI Studio to enable AI explanations.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
