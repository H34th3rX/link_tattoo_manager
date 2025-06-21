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
      create: (_) => ThemeProvider(),
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute, super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'LinkTattoo Manager',
      debugShowCheckedModeBanner: false,
      themeMode: themeProv.mode,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
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
  }
}