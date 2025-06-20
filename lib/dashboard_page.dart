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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Notificaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const NotificationTile(
              icon: Icons.event_available,
              title: 'Próxima cita en 30 minutos',
              subtitle: 'Ana López - 2:30 PM',
              time: '2:00 PM',
            ),
            const NotificationTile(
              icon: Icons.person_add,
              title: 'Nuevo cliente registrado',
              subtitle: 'Carlos Mendoza',
              time: '1:45 PM',
            ),
            const NotificationTile(
              icon: Icons.schedule,
              title: 'Recordatorio',
              subtitle: 'Revisar citas de mañana',
              time: '12:00 PM',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light 
          ? Colors.white 
          : null, // Forzar fondo blanco en modo claro
      appBar: AppBar(
        backgroundColor: const ui.Color(0xFFBDA206),
        title: const Text('Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {},
          ),
        ],
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
          : Drawer(child: NavPanel(user: user, onLogout: () => _logout(context))),
      body: Stack(
        children: [
          const BlurredBackground(),
          // Hacer que todo el Stack sea scrolleable
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                            width: 260,
                            child: NavPanel(user: user, onLogout: () => _logout(context))),
                        const VerticalDivider(width: 1),
                        const Expanded(child: MainContent()),
                      ],
                    )
                  : const MainContent(),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  const NotificationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1), // Corregido withOpacity
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const ui.Color(0xFFBDA206)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
    );
  }
}

class BlurredBackground extends StatelessWidget {
  const BlurredBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
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
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: 0.8)  // Más transparente para ver el logo
                : const Color.fromRGBO(0, 0, 0, 0.2),
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

class MainContent extends StatelessWidget {
  const MainContent({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 800;
    const double padding = 16;
    const double spacing = 12;
    final bool isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200), // Transición suave
      color: isLight ? Colors.transparent : null, // Transparente para ver el fondo difuminado
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 32 : padding, // Más padding en pantallas anchas
          vertical: padding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWide ? 700 : double.infinity, // Reducido de 900 a 700
            minHeight: size.height - 100, // Asegurar altura mínima para scroll
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grid de estadísticas 2x2
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Citas Hoy',
                      value: '8',
                      icon: Icons.event_available,
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: StatCard(
                      title: 'Clientes',
                      value: '156',
                      icon: Icons.people_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Próxima',
                      value: '2:30 PM',
                      icon: Icons.schedule,
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: StatCard(
                      title: 'Ingresos',
                      value: '\$12.4K',
                      icon: Icons.trending_up,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Botón principal Nueva Cita
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/appointments/new'),
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text(
                    'Nueva Cita',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const ui.Color(0xFFBDA206),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Botones secundarios
              Row(
                children: [
                  Expanded(
                    child: ActionCard(
                      icon: Icons.calendar_today,
                      label: 'Ver Citas',
                      color: isLight ? Colors.white.withValues(alpha: 0.95) : Colors.grey[800]!,
                      textColor: const ui.Color(0xFFBDA206),
                      onTap: () => Navigator.pushNamed(context, '/appointments'),
                    ),
                  ),
                  const SizedBox(width: spacing),
                  Expanded(
                    child: ActionCard(
                      icon: Icons.history,
                      label: 'Historial',
                      color: isLight ? Colors.white.withValues(alpha: 0.95) : Colors.grey[800]!,
                      textColor: const ui.Color(0xFFBDA206),
                      onTap: () => Navigator.pushNamed(context, '/calendar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Gráfico de ingresos
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white.withValues(alpha: 0.95) : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: isLight ? [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.15),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingresos de la Semana',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        primaryXAxis: const CategoryAxis(
                          majorGridLines: MajorGridLines(width: 0),
                          axisLine: AxisLine(width: 0),
                          majorTickLines: MajorTickLines(size: 0),
                        ),
                        primaryYAxis: const NumericAxis(
                          majorGridLines: MajorGridLines(
                            width: 0.5,
                            color: Colors.grey,
                            dashArray: [5, 5],
                          ),
                          axisLine: AxisLine(width: 0),
                          majorTickLines: MajorTickLines(size: 0),
                          labelFormat: '\${value}K',
                        ),
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          canShowMarker: true,
                          header: '',
                          format: 'point.x: \$point.yK',
                        ),
                        series: <CartesianSeries>[
                          SplineAreaSeries<_SalesData, String>(
                            dataSource: [
                              _SalesData('Lun', 5.2),
                              _SalesData('Mar', 7.8),
                              _SalesData('Mié', 6.4),
                              _SalesData('Jue', 9.1),
                              _SalesData('Vie', 8.7),
                              _SalesData('Sáb', 12.4),
                              _SalesData('Dom', 4.2),
                            ],
                            xValueMapper: (_SalesData data, _) => data.day,
                            yValueMapper: (_SalesData data, _) => data.amount,
                            splineType: SplineType.natural,
                            cardinalSplineTension: 0.9,
                            borderWidth: 3,
                            borderColor: const ui.Color(0xFFBDA206),
                            gradient: LinearGradient(
                              colors: [
                                const ui.Color(0xFFBDA206).withValues(alpha: 0.6),
                                const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            markerSettings: const MarkerSettings(
                              isVisible: true,
                              shape: DataMarkerType.circle,
                              borderWidth: 2,
                              borderColor: ui.Color(0xFFBDA206),
                              color: Colors.white,
                              width: 8,
                              height: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Sección de actividad reciente
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white.withValues(alpha: 0.95) : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: isLight ? [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.15),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actividad Reciente',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const ActivityTile(
                      title: 'Cita completada',
                      subtitle: 'Carlos Ruiz',
                      time: '10:30',
                    ),
                    const Divider(height: 1),
                    const ActivityTile(
                      title: 'Nueva cita',
                      subtitle: 'Ana López',
                      time: '09:15',
                    ),
                    const Divider(height: 1),
                    const ActivityTile(
                      title: 'Cliente llegó',
                      subtitle: 'Pedro Martín',
                      time: '08:45',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32), // Padding extra al final
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withValues(alpha: 0.95) : Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isLight ? [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isLight ? Colors.grey[700] : Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                icon,
                size: 24,
                color: const ui.Color(0xFFBDA206),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ui.Color(0xFFBDA206),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: textColor, size: 20),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: isLight ? 3 : 0,
          shadowColor: isLight ? Colors.grey.withValues(alpha: 0.4) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final String title, subtitle, time;

  const ActivityTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isLight ? Colors.grey[700] : Colors.grey[600], 
                    fontSize: 14
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: ui.Color(0xFFBDA206),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesData {
  final String day;
  final double amount;
  _SalesData(this.day, this.amount);
}