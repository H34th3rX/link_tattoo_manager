import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'supabase_service.dart';
import 'theme_provider.dart';
import 'login_page.dart' show LoginPage;
import 'register_page.dart' show RegisterPage;
import 'dashboard_page.dart' show DashboardPage;
import 'complete_profile_page.dart' show CompleteProfilePage;
import 'appointments_page.dart' show AppointmentsPage;
import 'clients_page.dart' show ClientsPage;
import 'reports_page.dart';
import 'client_profile_page.dart' show ClientProfilePage;
import 'client_history_page.dart' show ClientHistoryPage;
import 'calendar_page.dart' show CalendarPage;
import 'package:flutter_localizations/flutter_localizations.dart';
import './l10n/app_localizations.dart';
import 'localization_provider.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AuthService.initializeAuthState();
  
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
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute, super.key});
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocalizationProvider>(
      builder: (context, themeProvider, localizationProvider, child) {
        return MaterialApp(
          title: 'LinkTattoo Manager',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.mode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          initialRoute: initialRoute,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales.toList(),
          locale: localizationProvider.locale,
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            return localizationProvider.resolveLocale(supportedLocales, deviceLocale);
          },
          routes: {
            '/login': (_) => const LoginPage(),
            '/register': (_) => const RegisterPage(),
            '/complete_profile': (_) => const CompleteProfilePage(),
            '/dashboard': (_) => const DashboardPage(),
            '/profile': (context) => const ProfilePage(),
            '/appointments': (_) => const AppointmentsPage(),
            '/clients': (_) => const ClientsPage(),
            '/reports': (_) => ReportsPage(),
            '/client_profile': (context) {
              final client = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return ClientProfilePage(client: client);
            },
            '/client_history': (context) {
              final client = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return ClientHistoryPage(client: client);
            },
            '/calendar': (_) => const CalendarPage(),
          },
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData.light(useMaterial3: true).copyWith(
      primaryColor: const Color(0xFFBDA206),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBDA206),
        brightness: Brightness.light,
      ),
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
      primaryColor: const Color(0xFFBDA206),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBDA206),
        brightness: Brightness.dark,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}