import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import './integrations/clients_service.dart';

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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool initialIsDark = themeProvider.isDark;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: initialIsDark ? null : Colors.grey.shade50,
          appBar: CustomAppBar(
            title: 'Dashboard',
            onNotificationPressed: _showNotifications,
            isWide: isWide,
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
              BlurredBackground(isDark: initialIsDark),
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
                          child: MainContent(user: user, initialIsDark: initialIsDark),
                        ),
                      ],
                    )
                  : MainContent(user: user, initialIsDark: initialIsDark),
            ],
          ),
        );
      },
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

class AnimatedAppearance extends StatefulWidget {
  final Widget child;
  final int delay;
  final Duration duration;

  const AnimatedAppearance({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedAppearance> createState() => _AnimatedAppearanceState();
}

class _AnimatedAppearanceState extends State<AnimatedAppearance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class MainContent extends StatefulWidget {
  final User user;
  final bool initialIsDark;

  const MainContent({super.key, required this.user, required this.initialIsDark});

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  late Future<List<dynamic>> _activityData;
  late Future<int> _clientCount;

  @override
  void initState() {
    super.initState();
    final userId = widget.user.id;
    _activityData = Future.wait([
      ClientsService.getLatestClient(userId),
      ClientsService.getLatestAppointment(userId),
      ClientsService.getLastThreeAppointments(userId),
    ]).then((data) async {
      final latestAppointment = data[1] as Map?;
      final lastThreeAppointments = data[2] as List<Map>;
      if (latestAppointment != null) {
        final clientName = await ClientsService.getClientName(latestAppointment['client_id']);
        latestAppointment['clientName'] = clientName ?? 'Cliente desconocido';
      }
      for (var appointment in lastThreeAppointments) {
        appointment['clientName'] = await ClientsService.getClientName(appointment['client_id']);
      }
      return data;
    });
    _clientCount = ClientsService.getClientCountByEmployee(userId);
  }

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
                // Stats Cards con animación (delay: 0ms y 150ms)
                AnimatedAppearance(
                  delay: 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Citas Hoy',
                          value: '8',
                          icon: Icons.event_available,
                          isDark: widget.initialIsDark,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: StatCard(
                          title: 'Clientes',
                          valueFuture: _clientCount,
                          icon: Icons.people_outline,
                          isDark: widget.initialIsDark,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing),
                AnimatedAppearance(
                  delay: 150,
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Próxima',
                          value: '2:30 PM',
                          icon: Icons.schedule,
                          isDark: widget.initialIsDark,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: StatCard(
                          title: 'Ingresos',
                          value: '\$12.4K',
                          icon: Icons.trending_up,
                          isDark: widget.initialIsDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Botón Nueva Cita (delay: 300ms) - Updated to navigate to appointments with popup
                AnimatedAppearance(
                  delay: 300,
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/appointments').then((_) {
                          // Trigger the popup to open when returning from appointments page
                          // This will be handled in the appointments page
                        });
                      },
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
                        elevation: widget.initialIsDark ? 8 : 4,
                        shadowColor: const ui.Color(0xFFBDA206).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacing + 4),
                // Action Cards (delay: 450ms)
                AnimatedAppearance(
                  delay: 450,
                  child: Row(
                    children: [
                      Expanded(
                        child: ActionCard(
                          icon: Icons.history,
                          label: 'Ver Citas',
                          color: widget.initialIsDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                          textColor: const ui.Color(0xFFBDA206),
                          isDark: widget.initialIsDark,
                          onTap: () => Navigator.pushNamed(context, '/appointments'),
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: ActionCard(
                          icon: Icons.calendar_today,
                          label: 'Calendario',
                          color: widget.initialIsDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                          textColor: const ui.Color(0xFFBDA206),
                          isDark: widget.initialIsDark,
                          onTap: () => Navigator.pushNamed(context, '/calendar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Gráfico de ingresos (delay: 600ms)
                AnimatedAppearance(
                  delay: 600,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.initialIsDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.initialIsDark 
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
                            color: widget.initialIsDark ? Colors.white : Colors.black87,
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
                                color: widget.initialIsDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            primaryYAxis: NumericAxis(
                              majorGridLines: MajorGridLines(
                                width: 0.5,
                                color: widget.initialIsDark ? Colors.grey[700] : Colors.grey[300],
                                dashArray: const [5, 5],
                              ),
                              axisLine: const AxisLine(width: 0),
                              majorTickLines: const MajorTickLines(size: 0),
                              labelFormat: '\${value}K',
                              labelStyle: TextStyle(
                                color: widget.initialIsDark ? Colors.white70 : Colors.black87,
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
                ),
                const SizedBox(height: 40),
                // Actividad Reciente (delay: 750ms) - Improved design
                AnimatedAppearance(
                  delay: 750,
                  child: FutureBuilder(
                    future: _activityData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      final latestClient = snapshot.data![0] as Map?;
                      final latestAppointmentData = snapshot.data![1] as Map?;
                      final lastThreeAppointments = snapshot.data![2] as List<Map>;
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: widget.initialIsDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const ui.Color(0xFFBDA206).withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.initialIsDark 
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.timeline,
                                    color: ui.Color(0xFFBDA206),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Actividad Reciente',
                                  style: TextStyle(
                                    fontSize: 22, 
                                    fontWeight: FontWeight.bold,
                                    color: widget.initialIsDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ActivityCard(
                                      title: 'Último Cliente',
                                      icon: Icons.person_add,
                                      content: _buildLatestClient(latestClient, widget.initialIsDark),
                                      isDark: widget.initialIsDark,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ActivityCard(
                                      title: 'Última Cita',
                                      icon: Icons.event,
                                      content: _buildLatestAppointment(latestAppointmentData, widget.initialIsDark),
                                      isDark: widget.initialIsDark,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ActivityCard(
                                      title: 'Próximas Citas',
                                      icon: Icons.schedule,
                                      content: _buildLastThreeAppointments(lastThreeAppointments, widget.initialIsDark),
                                      isDark: widget.initialIsDark,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  ActivityCard(
                                    title: 'Último Cliente',
                                    icon: Icons.person_add,
                                    content: _buildLatestClient(latestClient, widget.initialIsDark),
                                    isDark: widget.initialIsDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ActivityCard(
                                    title: 'Última Cita',
                                    icon: Icons.event,
                                    content: _buildLatestAppointment(latestAppointmentData, widget.initialIsDark),
                                    isDark: widget.initialIsDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ActivityCard(
                                    title: 'Próximas Citas',
                                    icon: Icons.schedule,
                                    content: _buildLastThreeAppointments(lastThreeAppointments, widget.initialIsDark),
                                    isDark: widget.initialIsDark,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
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

  Widget _buildLatestClient(Map? client, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (client != null)
          ActivityTile(
            title: client['name'],
            subtitle: 'Registrado',
            time: DateFormat('dd/MM/yyyy').format(DateTime.parse(client['registration_date']).toLocal()),
            isDark: isDark,
            icon: Icons.person,
          )
        else
          Text(
            'No hay clientes registrados',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }

  Widget _buildLatestAppointment(Map? appointmentData, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (appointmentData != null)
          ActivityTile(
            title: appointmentData['clientName'] ?? 'Cliente desconocido',
            subtitle: 'Hora: ${DateTime.parse(appointmentData['start_time']).toLocal().toString().split(' ')[1].substring(0, 5)}',
            time: appointmentData['status'] ?? 'Sin estado',
            isDark: isDark,
            icon: Icons.event,
          )
        else
          Text(
            'No hay citas registradas',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }

  Widget _buildLastThreeAppointments(List<Map> appointments, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (appointments.isNotEmpty)
          Column(
            children: appointments.take(2).map((appointment) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActivityTile(
                  title: appointment['clientName'] ?? 'Cliente desconocido',
                  subtitle: 'Hora: ${DateTime.parse(appointment['start_time']).toLocal().toString().split(' ')[1].substring(0, 5)}',
                  time: appointment['status'] ?? 'Sin estado',
                  isDark: isDark,
                  icon: Icons.schedule,
                ),
              );
            }).toList(),
          )
        else
          Text(
            'No hay citas registradas',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }
}

class ActivityCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final bool isDark;

  const ActivityCard({
    super.key, 
    required this.title, 
    required this.icon,
    required this.content, 
    required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: const ui.Color(0xFFBDA206),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String? value;
  final Future<int>? valueFuture;
  final IconData icon;
  final bool isDark;

  const StatCard({
    super.key,
    required this.title,
    this.value,
    this.valueFuture,
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
          if (value != null)
            Text(
              value!,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ui.Color(0xFFBDA206),
              ),
            )
          else if (valueFuture != null)
            Expanded(
              child: FutureBuilder<int>(
                future: valueFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      '',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ui.Color(0xFFBDA206),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      '0',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ui.Color(0xFFBDA206),
                      ),
                    );
                  }
                  return Text(
                    '${snapshot.data ?? 0}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ui.Color(0xFFBDA206),
                    ),
                  );
                },
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
  final IconData icon;

  const ActivityTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700]?.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: const ui.Color(0xFFBDA206),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (time.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  color: ui.Color(0xFFBDA206),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
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