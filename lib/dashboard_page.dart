import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _userName;
  late Future<void> _loadUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData = _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = Supabase.instance.client.auth.currentUser!;
    final snapshot = await Supabase.instance.client
        .from('employees')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _userName = snapshot?['username'] as String? ?? user.email!.split('@')[0];
      });
    }
  }

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDark;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: isDark ? null : Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: isDark 
                ? const Color(0xFF2A2A2A)
                : const ui.Color(0xFFBDA206),
            title: Text('Dashboard',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, 
                  fontWeight: FontWeight.bold
                )),
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
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
              : Drawer(
                  child: _userName != null
                      ? NavPanel(user: user, onLogout: () => _logout(context), userName: _userName!)
                      : const Center(child: CircularProgressIndicator()),
                ),
          body: Stack(
            children: [
              BlurredBackground(isDark: isDark),
              isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: _userName != null
                              ? NavPanel(
                                  user: user,
                                  onLogout: () => _logout(context),
                                  userName: _userName!,
                                )
                              : const Center(child: CircularProgressIndicator()),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: MainContent(isDark: isDark),
                        ),
                      ],
                    )
                  : MainContent(isDark: isDark),
            ],
          ),
        );
      },
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
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
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
  final bool isDark;
  
  const BlurredBackground({super.key, required this.isDark});

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
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class MainContent extends StatelessWidget {
  final bool isDark;
  
  const MainContent({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 800;
    const double padding = 24;
    const double spacing = 16;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : padding,
              vertical: padding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Citas Hoy',
                        value: '8',
                        icon: Icons.event_available,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: StatCard(
                        title: 'Clientes',
                        value: '156',
                        icon: Icons.people_outline,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Próxima',
                        value: '2:30 PM',
                        icon: Icons.schedule,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: StatCard(
                        title: 'Ingresos',
                        value: '\$12.4K',
                        icon: Icons.trending_up,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
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
                      elevation: isDark ? 8 : 4,
                      shadowColor: const ui.Color(0xFFBDA206).withValues(alpha: 0.4),
                    ),
                  ),
                ),
                SizedBox(height: spacing + 4),
                Row(
                  children: [
                    Expanded(
                      child: ActionCard(
                        icon: Icons.calendar_today,
                        label: 'Ver Citas',
                        color: isDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                        textColor: const ui.Color(0xFFBDA206),
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(context, '/appointments'),
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: ActionCard(
                        icon: Icons.history,
                        label: 'Historial',
                        color: isDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                        textColor: const ui.Color(0xFFBDA206),
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(context, '/calendar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingresos de la Semana',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        child: SfCartesianChart(
                          plotAreaBorderWidth: 0,
                          backgroundColor: Colors.transparent,
                          primaryXAxis: CategoryAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            axisLine: const AxisLine(width: 0),
                            majorTickLines: const MajorTickLines(size: 0),
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          primaryYAxis: NumericAxis(
                            majorGridLines: MajorGridLines(
                              width: 0.5,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              dashArray: const [5, 5],
                            ),
                            axisLine: const AxisLine(width: 0),
                            majorTickLines: const MajorTickLines(size: 0),
                            labelFormat: '\${value}K',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
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
                const SizedBox(height: 40),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.15),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actividad Reciente',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ActivityTile(
                        title: 'Cita completada',
                        subtitle: 'Carlos Ruiz',
                        time: '10:30',
                        isDark: isDark,
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      ActivityTile(
                        title: 'Nueva cita',
                        subtitle: 'Ana López',
                        time: '09:15',
                        isDark: isDark,
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      ActivityTile(
                        title: 'Cliente llegó',
                        subtitle: 'Pedro Martín',
                        time: '08:45',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final bool isDark;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
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
  final bool isDark;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
          elevation: isDark ? 6 : 3,
          shadowColor: isDark 
              ? Colors.black.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.4),
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
  final bool isDark;

  const ActivityTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 14,
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