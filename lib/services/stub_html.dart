// stub_html.dart
// Este archivo proporciona implementaciones stub para funciones HTML
// cuando se ejecuta en plataformas que no son web (Android/iOS)

class Window {
  Location get location => Location();
  History get history => History();
  Storage get localStorage => Storage();
  Storage get sessionStorage => Storage();
}

class Location {
  String get href => '';
  void reload() {}
}

class History {
  void replaceState(dynamic data, String title, String url) {}
}

class Storage {
  void removeWhere(bool Function(String key, String value) test) {}
}

final window = Window();