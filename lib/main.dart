import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';
import 'supabase_service.dart';
import 'theme_provider.dart';
import 'login_page.dart' show LoginPage;
import 'register_page.dart' show RegisterPage;
import 'dashboard_page.dart' show DashboardPage;
import 'complete_profile_page.dart'; // Importación simplificada
import 'loading_screen.dart' show LoadingScreen;
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

// Definir una GlobalKey para el Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  
  // Configurar el listener de deep links para manejar confirmaciones de email
  _setupDeepLinkListener();
  
  // Inicializar ThemeProvider y esperar a que cargue el tema
  final themeProvider = ThemeProvider();
  await themeProvider.initialize(); // Esperar la inicialización del tema

  // Inicializar LocalizationProvider
  final localizationProvider = LocalizationProvider();

  String initialRoute = '/loading'; // Cambiar a loading para verificar usuario
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localizationProvider),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

// Configurar listener para deep links
void _setupDeepLinkListener() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedIn && session != null) {
      // Si el usuario se ha autenticado (ej. después de la confirmación de email o login directo)
      // Navegar a la pantalla de carga para determinar la ruta correcta
      if (navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted) {
        Navigator.of(navigatorKey.currentContext!).pushReplacementNamed('/loading');
      }
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
          navigatorKey: navigatorKey, // Añadir esta línea
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
            '/loading': (_) => const LoadingScreen(),
            '/login': (_) => const LoginPage(),
            '/register': (_) => const RegisterPage(),
            '/password_recovery': (_) => const PasswordRecoveryPage(),
            '/complete_profile': (_) => const CompleteProfilePage(), // Usar la página unificada
            '/dashboard': (_) => const DashboardPage(),
            '/client_dashboard': (_) => const ClientDashboardPage(),
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

// Dashboard de cliente mejorado
class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Dashboard Cliente',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFBDA206),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/logo.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Color.fromRGBO(0, 0, 0, 0.7),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(15, 19, 21, 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFBDA206),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBDA206).withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBDA206), Color(0xFF8B7505)],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido Cliente',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu área personal está en desarrollo',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Botones de funcionalidades futuras (restaurados)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildFeatureButton(
                      icon: Icons.calendar_today,
                      label: 'Mis Citas',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidad en desarrollo'),
                            backgroundColor: Color(0xFFBDA206),
                          ),
                        );
                      },
                    ),
                    _buildFeatureButton(
                      icon: Icons.history,
                      label: 'Historial',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidad en desarrollo'),
                            backgroundColor: Color(0xFFBDA206),
                          ),
                        );
                      },
                    ),
                    _buildFeatureButton(
                      icon: Icons.person_outline,
                      label: 'Mi Perfil',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidad en desarrollo'),
                            backgroundColor: Color(0xFFBDA206),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFBDA206).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFBDA206).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFFBDA206),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}