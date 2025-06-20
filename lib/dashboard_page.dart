import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final nav = Navigator.of(context);
    await Supabase.instance.client.auth.signOut();
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final User user = Supabase.instance.client.auth.currentUser!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFBDA206),
        title: const Text('Dashboard', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: isWide
            ? null
            : Builder(builder: (ctx) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                );
              }),
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: NavPanel(user: user, onLogout: () => _logout(context)),
            ),
      body: Stack(
        children: [
          const BlurredBackground(),
          isWide
              ? Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: NavPanel(user: user, onLogout: () => _logout(context)),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(child: MainContent()),
                  ],
                )
              : const MainContent(),
        ],
      ),
    );
  }
}

class BlurredBackground extends StatelessWidget {
  const BlurredBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double alpha = isDark ? 0.2 : 0.2;
    return Positioned.fill(
      child: Center(
        child: Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/logo.png'),
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(
                isDark
                    ? Color.fromRGBO(0, 0, 0, alpha)
                    : Color.fromRGBO(255, 255, 255, alpha),
                BlendMode.dstATop,
              ),
            ),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
    );
  }
}

class NavPanel extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;

  const NavPanel({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final String current = ModalRoute.of(context)?.settings.name ?? '';
    final bool isDark = Provider.of<ThemeProvider>(context).mode == ThemeMode.dark;

    Widget navTile(IconData icon, String label, String route) {
      final bool selected = current == route;
      return ListTile(
        leading: Icon(
          icon,
          color: selected ? const ui.Color(0xFFBDA206): null,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : null,
            color: selected ? const ui.Color(0xFFBDA206) : null,
          ),
        ),
        selected: selected,
        onTap: () => Navigator.of(context).pushReplacementNamed(route),
      );
    }

    return Column(
      children: [
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(color: const ui.Color(0xFFBDA206)),
          accountName: Text(user.email!.split('@')[0],
              style: const TextStyle(color: Colors.black)),
          accountEmail:
              Text(user.email!, style: const TextStyle(color: Colors.black54)),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              user.email![0].toUpperCase(),
              style: TextStyle(fontSize: 24, color: const ui.Color(0xFFBDA206)),
            ),
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
    );
  }
}

class MainContent extends StatelessWidget {
  const MainContent({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 800;
    final double padding = 24;
    final double spacing = 16;
    final double gridWidth = size.width - padding * 2;
    final int columns = isWide ? 4 : 2;
    final double cardSize = (gridWidth - spacing * (columns - 1)) / columns;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: isWide ? 900 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  StatCard(
                    size: cardSize,
                    title: 'Citas Hoy',
                    value: '8',
                    icon: Icons.event_available,
                  ),
                  StatCard(
                    size: cardSize,
                    title: 'Clientes',
                    value: '156',
                    icon: Icons.people_outline,
                  ),
                  StatCard(
                    size: cardSize,
                    title: 'Próxima',
                    value: '2:30 PM',
                    icon: Icons.schedule,
                  ),
                  StatCard(
                    size: cardSize,
                    title: 'Ingresos',
                    value: '\$12.4K',
                    icon: Icons.attach_money,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  ActionCard(
                    icon: Icons.add,
                    label: 'Nueva Cita',
                    color: const ui.Color(0xFFBDA206),
                    onTap: () =>
                        Navigator.pushNamed(context, '/appointments/new'),
                  ),
                  ActionCard(
                    icon: Icons.calendar_today,
                    label: 'Ver Citas',
                    color: const ui.Color(0xFFBDA206),
                    onTap: () =>
                        Navigator.pushNamed(context, '/appointments'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ActionCard(
                  icon: Icons.calendar_view_month,
                  label: 'Calendario',
                  color: const ui.Color(0xFFBDA206),
                  onTap: () => Navigator.pushNamed(context, '/calendar'),
                ),
              ),
              const SizedBox(height: 32),

              const Text('Ingresos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 240,
                child: SfCartesianChart(
                  primaryXAxis:
                      NumericAxis(majorGridLines: const MajorGridLines(width: 0)),
                  primaryYAxis:
                      NumericAxis(majorGridLines: const MajorGridLines(width: 0)),
                  series: <SplineAreaSeries<_SalesData, int>>[
                    SplineAreaSeries<_SalesData, int>(
                      dataSource: [
                        _SalesData(0, 5),
                        _SalesData(1, 7),
                        _SalesData(2, 6),
                        _SalesData(3, 8),
                        _SalesData(4, 7),
                        _SalesData(5, 9),
                        _SalesData(6, 8),
                      ],
                      xValueMapper: (_SalesData sales, _) => sales.day,
                      yValueMapper: (_SalesData sales, _) => sales.amount,
                      borderColor: const ui.Color(0xFFBDA206),
                      borderWidth: 2,
                      gradient: LinearGradient(
                        colors: [
                          Color.fromRGBO(255, 193, 7, 0.4),
                          Color.fromRGBO(255, 193, 7, 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text('Actividad Reciente',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListView(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: const [
                  ActivityTile(title: 'Cita completada', subtitle: 'Carlos Ruiz 10:30'),
                  ActivityTile(title: 'Nueva cita', subtitle: 'Ana López 09:15'),
                  ActivityTile(title: 'Cliente llegó', subtitle: 'Pedro Martín 08:45'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final double size;
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.size,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 28, color: Theme.of(context).colorScheme.primary),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width >= 800
        ? 160
        : (MediaQuery.of(context).size.width - 48) / 2;
    return SizedBox(
      width: width,
      height: 80,
      child: Card(
        color: color,
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: Colors.white),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const ActivityTile({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.check_circle_outline),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _SalesData {
  final int day;
  final double amount;
  _SalesData(this.day, this.amount);
}
