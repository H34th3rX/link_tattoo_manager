import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_provider.dart';

class NavPanel extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const NavPanel({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final String current = ModalRoute.of(context)?.settings.name ?? '';
    final bool isDark = Provider.of<ThemeProvider>(context).mode == ThemeMode.dark;
    const ui.Color highlight = ui.Color(0xFFBDA206);

    Widget navTile(IconData icon, String label, String route) {
      final selected = current == route;
      return ListTile(
        leading: Icon(icon, color: selected ? highlight : null),
        title: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.bold : null,
                color: selected ? highlight : null)),
        selected: selected,
        onTap: () => Navigator.of(context).pushReplacementNamed(route),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Theme.of(context).brightness == Brightness.light 
          ? Colors.transparent  // Transparente para ver el fondo difuminado
          : null,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: highlight),
            accountName: Text(user.email!.split('@')[0],
                style: const TextStyle(color: Colors.black)),
            accountEmail:
                Text(user.email!, style: const TextStyle(color: Colors.black54)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(user.email![0].toUpperCase(),
                  style: const TextStyle(fontSize: 24, color: highlight)),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                navTile(Icons.dashboard, 'Dashboard', '/dashboard'),
                navTile(Icons.event_available, 'Citas', '/appointments'),
                navTile(Icons.calendar_month, 'Calendario', '/calendar'),
                navTile(Icons.people, 'Clientes', '/clients'),
                navTile(Icons.picture_as_pdf, 'Reportes', '/reports'),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Modo Oscuro'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) =>
                  Provider.of<ThemeProvider>(context, listen: false).toggle(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}