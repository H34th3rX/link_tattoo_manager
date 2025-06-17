import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  // Si hay sesión activa, vamos al dashboard
  final user = Supabase.instance.client.auth.currentUser;
  runApp(MyApp(initialRoute: user == null ? '/login' : '/dashboard'));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LinkTattooManager',
       debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginPage(),
        '/dashboard': (_) => const DashboardPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}
