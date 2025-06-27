import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'theme_provider.dart';
import 'login_page.dart' show LoginPage;
import 'register_page.dart' show RegisterPage;
import 'dashboard_page.dart' show DashboardPage;
import 'complete_profile_page.dart' show CompleteProfilePage;
//import 'appointments_list_page.dart';
//import 'appointment_edit_page.dart';
//import 'clients_page.dart';
//import 'reports_page.dart';
//import 'calendar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  final user = Supabase.instance.client.auth.currentUser;
  String initialRoute = '/login';
  
  if (user != null) {
    final response = await Supabase.instance.client
        .from('employees')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    initialRoute = response != null ? '/dashboard' : '/complete_profile';
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(), // Se carga automáticamente con SharedPreferences
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'LinkTattoo Manager',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          initialRoute: initialRoute,
          routes: {
            '/login': (_) => LoginPage(),
            '/register': (_) => RegisterPage(),
            '/complete_profile': (_) => CompleteProfilePage(),
            '/dashboard': (_) => DashboardPage(),
            //'/appointments': (_) => AppointmentsListPage(),
            //'/appointments/new': (_) => AppointmentEditPage(),
            //'/clients': (_) => ClientsPage(),
            //'/reports': (_) => ReportsPage(),
            //'/calendar': (_) => CalendarPage(),
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData.light(useMaterial3: true).copyWith(
      // Personalización adicional del tema claro si es necesaria
      primaryColor: const Color(0xFFBDA206),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBDA206),
        brightness: Brightness.light,
      ),
      // Duración consistente para todas las animaciones de tema
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData.dark(useMaterial3: true).copyWith(
      // Personalización adicional del tema oscuro si es necesaria
      primaryColor: const Color(0xFFBDA206),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBDA206),
        brightness: Brightness.dark,
      ),
      // Duración consistente para todas las animaciones de tema
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}