import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    // Volvemos al login y limpiamos el stack
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Bienvenido, ${user.email}!',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('Gestionar Citas'),
              onPressed: () {
                // TODO: Navigator.pushNamed(context, '/appointments');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text('Gestionar Clientes'),
              onPressed: () {
                // TODO: Navigator.pushNamed(context, '/clients');
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Reportes'),
              onPressed: () {
                // TODO: Navigator.pushNamed(context, '/reports');
              },
            ),
          ],
        ),
      ),
    );
  }
}
