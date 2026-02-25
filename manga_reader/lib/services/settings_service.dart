import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  bool _immersiveMode = true;
  bool _showOverlay = true;

  bool get immersiveMode => _immersiveMode;
  bool get showOverlay => _showOverlay;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _immersiveMode = prefs.getBool('immersive_mode') ?? true;
    _showOverlay = prefs.getBool('show_overlay') ?? true;
    notifyListeners();
  }

  Future<void> setImmersiveMode(bool value) async {
    _immersiveMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('immersive_mode', value);
    notifyListeners();
  }

  Future<void> setShowOverlay(bool value) async {
    _showOverlay = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_overlay', value);
    notifyListeners();
  }
}
