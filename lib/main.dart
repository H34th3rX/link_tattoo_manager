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
import 'password_recovery_page.dart'; 
import 'reset_password_page.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import './l10n/app_localizations.dart';
import 'localization_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  // Configurar el listener de deep links para manejar confirmaciones de email
  _setupDeepLinkListener();
  
  // Inicializar ThemeProvider y esperar a que cargue el tema
  final themeProvider = ThemeProvider();
  await themeProvider.initialize(); // Esperar la inicialización del tema

  // Inicializar LocalizationProvider (asumiendo que también podría tener una inicialización asíncrona)
  final localizationProvider = LocalizationProvider();
  // Si LocalizationProvider también carga datos asíncronamente, descomenta la siguiente línea:
  // await localizationProvider.initialize(); 

  String initialRoute = '/login';
  
  runApp(
    MultiProvider(
      providers: [
        // Usar .value para proporcionar la instancia ya inicializada
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localizationProvider),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

// Configurar listener para deep links
void _setupDeepLinkListener() {
  // Escuchar cambios en el estado de autenticación para manejar confirmaciones
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;
    
    if (event == AuthChangeEvent.signedIn && session != null) {
      // Si el usuario se registró y confirmó su email, redirigir al dashboard
      print('Usuario confirmado y logueado: ${session.user.email}');
    }
  });
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
            '/password_recovery': (_) => const PasswordRecoveryPage(), // Ruta para la página de recuperación
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
          onGenerateRoute: (settings) {
            // Manejar rutas con parámetros, como la página de restablecimiento de contraseña
            if (settings.name == '/reset_password') {
              final args = settings.arguments as Map<String, dynamic>?;
              final userEmail = args?['userEmail'] as String?;
              
              if (userEmail != null) {
                return MaterialPageRoute(
                  builder: (context) => ResetPasswordPage(userEmail: userEmail),
                );
              }
            }
            return null;
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