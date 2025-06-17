import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Rellena con tus datos
  static const String _url = 'https://xgwhuhmubomoqimiqfqt.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhnd2h1aG11Ym9tb3FpbWlxZnF0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxMDkyNTIsImV4cCI6MjA2NTY4NTI1Mn0.bT1BtbfPcveLOKq0P-qsp-bYfNSQP7x4vJG9sRNXAiE';

  /// Inicializa Supabase al arrancar la app
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  /// Cliente global para consultas
  static SupabaseClient get client => Supabase.instance.client;
}
