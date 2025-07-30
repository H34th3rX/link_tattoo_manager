import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.light; // Default to light initially
  bool _isInitialized = false;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;
  bool get isInitialized => _isInitialized;

  // El constructor ya no llama a _loadTheme()
  ThemeProvider();

  // Nueva función de inicialización asíncrona
  Future<void> initialize() async {
    await _loadTheme(); // Espera a que el tema se cargue
    _isInitialized = true;
    notifyListeners(); // Notifica a los listeners una vez que la inicialización está completa
  }

  void toggle() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners(); // Notifica inmediatamente para el cambio de tema
  }

  void setTheme(ThemeMode mode) {
    if (_mode != mode) {
      _mode = mode;
      _saveTheme();
      notifyListeners();
    }
  }

  void setLight() => setTheme(ThemeMode.light);
  void setDark() => setTheme(ThemeMode.dark);
  void setSystem() => setTheme(ThemeMode.system);

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? 0;
      _mode = ThemeMode.values[themeIndex];
    } catch (e) {
      debugPrint('Error loading theme: $e');
      _mode = ThemeMode.light; // Default to light on error
    }
    // No llamar a notifyListeners aquí, se hace en initialize()
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _mode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}