import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.light;
  bool _isInitialized = false;
  
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;
  bool get isInitialized => _isInitialized;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  void toggle() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
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
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Si hay error, mantener tema por defecto
      _mode = ThemeMode.light;
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _mode.index);
    } catch (e) {
      // Error al guardar, pero no es crítico
      debugPrint('Error saving theme: $e');
    }
  }
}