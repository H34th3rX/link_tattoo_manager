import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LocalizationProvider extends ChangeNotifier {
  Locale? _locale;
  String _languagePreference = 'system'; // 'system', 'en', 'es'

  Locale? get locale => _locale;
  String get languagePreference => _languagePreference;

  LocalizationProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _languagePreference = prefs.getString('languagePreference') ?? 'system';
    _setLocaleFromPreference();
  }

  Future<void> setLanguagePreference(String preference) async {
    if (_languagePreference == preference) return;
    _languagePreference = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languagePreference', preference);
    _setLocaleFromPreference();
    notifyListeners();
  }

  void _setLocaleFromPreference() {
    if (_languagePreference == 'en') {
      _locale = const Locale('en');
    } else if (_languagePreference == 'es') {
      _locale = const Locale('es');
    } else {
      _locale = null; // Usar el locale del sistema
    }
  }

  // Método para resolver el locale basado en la preferencia del usuario
  Locale? resolveLocale(Iterable<Locale> supportedLocales, Locale? deviceLocale) {
    if (_languagePreference == 'system') {
      return deviceLocale;
    } else if (_languagePreference == 'en') {
      return const Locale('en');
    } else if (_languagePreference == 'es') {
      return const Locale('es');
    }
    return deviceLocale; // Fallback
  }
}
