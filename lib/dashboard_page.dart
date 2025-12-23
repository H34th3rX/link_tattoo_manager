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
import './integrations/appointments_service.dart';
import './l10n/app_localizations.dart';

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
    final AppLocalizations localizations = AppLocalizations.of(context)!;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final bool isDark = themeProvider.isDark;
            
            return Scaffold(
              backgroundColor: isDark ? null : Colors.grey.shade50,
              appBar: CustomAppBar(
                title: localizations.dashboardPageTitle,
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
                              child: MainContent(user: user, isDark: isDark, localizations: localizations),
                            ),
                          ],
                        )
                      : MainContent(user: user, isDark: isDark, localizations: localizations),
                ],
              ),
            );
          },
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
  final bool isDark;
  final AppLocalizations localizations;
  const MainContent({super.key, required this.user, required this.isDark, required this.localizations});

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  late Future<List<dynamic>> _activityData;
  late Future<int> _clientCount;
  late Future<double> _totalRevenue;
  late Future<int> _todayConfirmedCount;
  late Future<Map<String, dynamic>?> _nextConfirmedAppointment;
  late Future<List<Map<String, dynamic>>> _weeklyRevenueData;
  late Future<Map<String, int>> _statusDistribution;
  late Future<List<Map<String, dynamic>>> _topServices;
  late Future<Map<String, int>> _dayOfWeekData;

  @override
  void initState() {
    super.initState();
    final userId = widget.user.id;
    
    // Datos existentes
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
    
    // Datos dinámicos actualizados
    _totalRevenue = AppointmentsService.getCompletedAppointmentsRevenue(userId);
    _todayConfirmedCount = AppointmentsService.getTotalConfirmedAppointmentsCount(userId);
    _nextConfirmedAppointment = AppointmentsService.getNextConfirmedAppointment(userId);
    
    // NUEVO: Cargar datos reales del gráfico semanal
    _weeklyRevenueData = AppointmentsService.getWeeklyRevenueData(userId);
    _statusDistribution = AppointmentsService.getAppointmentsStatusDistribution(userId);
    _topServices = AppointmentsService.getTopServices(userId, limit: 5);
    _dayOfWeekData = AppointmentsService.getAppointmentsByDayOfWeek(userId);
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
                        title: widget.localizations.appointmentsConfirmed,
                        valueFuture: _todayConfirmedCount,
                        icon: Icons.event_available,
                        isDark: widget.isDark,
                      ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: StatCard(
                          title: widget.localizations.clientsStat,
                          valueFuture: _clientCount,
                          icon: Icons.people_outline,
                          isDark: widget.isDark,
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
                        child: NextAppointmentCard(
                          title: widget.localizations.nextAppointmentShort,
                          appointmentFuture: _nextConfirmedAppointment,
                          icon: Icons.schedule,
                          isDark: widget.isDark,
                          localizations: widget.localizations,
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: RevenueCard(
                          title: widget.localizations.income,
                          revenueFuture: _totalRevenue,
                          icon: Icons.trending_up,
                          isDark: widget.isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Botón Nueva Cita
                AnimatedAppearance(
                  delay: 300,
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navegar a la página de citas y pasar un argumento para abrir el popup
                        Navigator.pushNamed(
                          context,
                          '/appointments',
                          arguments: {'openNewAppointmentPopup': true},
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: Text(
                        widget.localizations.newAppointment,
                        style: const TextStyle(
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
                        elevation: widget.isDark ? 8 : 4,
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
                          label: widget.localizations.viewAppointments,
                          color: widget.isDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                          textColor: const ui.Color(0xFFBDA206),
                          isDark: widget.isDark,
                          onTap: () => Navigator.pushNamed(context, '/appointments'),
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: ActionCard(
                          icon: Icons.calendar_today,
                          label: widget.localizations.calendarAction,
                          color: widget.isDark ? Colors.grey[800]! : Colors.white.withValues(alpha: 0.95),
                          textColor: const ui.Color(0xFFBDA206),
                          isDark: widget.isDark,
                          onTap: () => Navigator.pushNamed(context, '/calendar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Gráfico de ingresos (delay: 600ms) - ACTUALIZADO CON DATOS REALES
                AnimatedAppearance(
                  delay: 600,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isDark
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
                          widget.localizations.weeklyRevenue,
                          style: TextStyle(
                            fontSize: 20,
                             fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 220,
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _weeklyRevenueData,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(ui.Color(0xFFBDA206)),
                                ));
                              }
                              
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error cargando datos',
                                    style: TextStyle(
                                      color: widget.isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                );
                              }
                              
                              final weeklyData = snapshot.data ?? [];
                              
                              // Convertir los datos al formato esperado por el gráfico
                              final chartData = weeklyData.map((data) => _SalesData(
                                data['day'] as String,
                                (data['amount'] as num).toDouble(),
                              )).toList();
                              
                              return SfCartesianChart(
                                plotAreaBorderWidth: 0,
                                backgroundColor: Colors.transparent,
                                primaryXAxis: CategoryAxis(
                                  majorGridLines: const MajorGridLines(width: 0),
                                  axisLine: const AxisLine(width: 0),
                                  majorTickLines: const MajorTickLines(size: 0),
                                  labelStyle: TextStyle(
                                    color: widget.isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                primaryYAxis: NumericAxis(
                                  majorGridLines: MajorGridLines(
                                    width: 0.5,
                                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                                    dashArray: const [5, 5],
                                  ),
                                  axisLine: const AxisLine(width: 0),
                                  majorTickLines: const MajorTickLines(size: 0),
                                  labelFormat: '\${value}K',
                                  labelStyle: TextStyle(
                                    color: widget.isDark ? Colors.white70 : Colors.black87,
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
                                    dataSource: chartData,
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fila de gráficos nuevos (Pastel y Dona)
                const SizedBox(height: 32),
                AnimatedAppearance(
                  delay: 600,
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Gráfico de Pastel - Estados de Citas
                            Expanded(
                              child: _buildPieChart(),
                            ),
                            const SizedBox(width: 16),
                            // Gráfico de Dona - Servicios Populares
                            Expanded(
                              child: _buildDoughnutChart(),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPieChart(),
                            const SizedBox(height: 16),
                            _buildDoughnutChart(),
                          ],
                        ),
                ),

                // Gráfico Radial - Citas por día de la semana
                const SizedBox(height: 32),
                AnimatedAppearance(
                  delay: 750,
                  child: _buildRadialChart(),
                ),

                // Actividad Reciente (delay: 750ms) - Improved design
                const SizedBox(height: 40),
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
                          color: widget.isDark ? Colors.grey[850] : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const ui.Color(0xFFBDA206).withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isDark
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
                                  widget.localizations.recentActivity,
                                  style: TextStyle(
                                    fontSize: 22,
                                     fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : Colors.black87,
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
                                      title: widget.localizations.latestClient,
                                      icon: Icons.person_add,
                                      content: _buildLatestClient(latestClient, widget.isDark, widget.localizations),
                                      isDark: widget.isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ActivityCard(
                                      title: widget.localizations.latestAppointment,
                                      icon: Icons.event,
                                      content: _buildLatestAppointment(latestAppointmentData, widget.isDark, widget.localizations),
                                      isDark: widget.isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ActivityCard(
                                      title: widget.localizations.upcomingAppointments,
                                      icon: Icons.schedule,
                                      content: _buildLastThreeAppointments(lastThreeAppointments, widget.isDark, widget.localizations),
                                      isDark: widget.isDark,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  ActivityCard(
                                    title: widget.localizations.latestClient,
                                    icon: Icons.person_add,
                                    content: _buildLatestClient(latestClient, widget.isDark, widget.localizations),
                                    isDark: widget.isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ActivityCard(
                                    title: widget.localizations.latestAppointment,
                                    icon: Icons.event,
                                    content: _buildLatestAppointment(latestAppointmentData, widget.isDark, widget.localizations),
                                    isDark: widget.isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  ActivityCard(
                                    title: widget.localizations.upcomingAppointments,
                                    icon: Icons.schedule,
                                    content: _buildLastThreeAppointments(lastThreeAppointments, widget.isDark, widget.localizations),
                                    isDark: widget.isDark,
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

  Widget _buildLatestClient(Map? client, bool isDark, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (client != null)
          ActivityTile(
            title: client['name'],
            subtitle: localizations.registered,
            time: DateFormat('dd/MM/yyyy').format(DateTime.parse(client['registration_date']).toLocal()),
            isDark: isDark,
            icon: Icons.person,
          )
        else
          Text(
            localizations.noClientsRegistered,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }

  Widget _buildLatestAppointment(Map? appointmentData, bool isDark, AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (appointmentData != null)
          ActivityTile(
            title: appointmentData['clientName'] ?? localizations.unknownClient,
            subtitle: '${localizations.time}: ${DateTime.parse(appointmentData['start_time']).toLocal().toString().split(' ')[1].substring(0, 5)}',
            time: appointmentData['status'] ?? localizations.noStatus,
            isDark: isDark,
            icon: Icons.event,
          )
        else
          Text(
            localizations.noAppointmentsRegistered,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }

  Widget _buildLastThreeAppointments(List<Map> appointments, bool isDark, AppLocalizations localizations) {
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
                  title: appointment['clientName'] ?? localizations.unknownClient,
                  subtitle: '${localizations.time}: ${DateTime.parse(appointment['start_time']).toLocal().toString().split(' ')[1].substring(0, 5)}',
                  time: appointment['status'] ?? localizations.noStatus,
                  isDark: isDark,
                  icon: Icons.schedule,
                ),
              );
            }).toList(),
          )
        else
          Text(
            localizations.noAppointmentsRegistered,
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
      ],
    );
  }

  /// Gráfico de Pastel - Distribución de Estados de Citas
  Widget _buildPieChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  size: 20,
                  color: ui.Color(0xFFBDA206),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Estados de Citas - Este Mes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Gráfico
          FutureBuilder<Map<String, int>>(
            future: _statusDistribution,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator(color: ui.Color(0xFFBDA206))),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.values.every((v) => v == 0)) {
                return SizedBox(
                  height: 250,
                  child: Center(
                    child: Text(
                      'No hay datos para este mes',
                      style: TextStyle(
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              
              final data = snapshot.data!;
              final chartData = data.entries
                  .where((e) => e.value > 0)
                  .map((e) => _ChartData(e.key, e.value))
                  .toList();
              
              return SizedBox(
                height: 250,
                child: SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 11,
                    ),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y citas',
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  series: <CircularSeries>[
                    PieSeries<_ChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (_ChartData data, _) => data.label,
                      yValueMapper: (_ChartData data, _) => data.value,
                      pointColorMapper: (_ChartData data, _) => _getStatusColor(data.label),
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        textStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      dataLabelMapper: (_ChartData data, _) => '${data.value}',
                      enableTooltip: true,
                      explode: true,
                      explodeIndex: 0,
                      explodeOffset: '5%',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Gráfico de Dona - Servicios Más Populares
  Widget _buildDoughnutChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.donut_large,
                  size: 20,
                  color: ui.Color(0xFFBDA206),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top 5 Servicios - Este Mes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Gráfico
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _topServices,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator(color: ui.Color(0xFFBDA206))),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SizedBox(
                  height: 250,
                  child: Center(
                    child: Text(
                      'No hay servicios este mes',
                      style: TextStyle(
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              
              final data = snapshot.data!;
              final chartData = data.map((e) {
                String serviceName = e['service'] as String;
                if (serviceName.length > 20) {
                  serviceName = '${serviceName.substring(0, 20)}...';
                }
                return _ChartData(serviceName, e['count'] as int);
              }).toList();
              
              return SizedBox(
                height: 250,
                child: SfCircularChart(
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    overflowMode: LegendItemOverflowMode.wrap,
                    textStyle: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 10,
                    ),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y veces',
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  series: <CircularSeries>[
                    DoughnutSeries<_ChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (_ChartData data, _) => data.label,
                      yValueMapper: (_ChartData data, _) => data.value,
                      pointColorMapper: (_ChartData data, _) => _getServiceColor(chartData.indexOf(data)),
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.outside,
                        textStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      dataLabelMapper: (_ChartData data, _) => '${data.value}',
                      enableTooltip: true,
                      innerRadius: '60%',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Gráfico Radial - Citas por Día de la Semana
  Widget _buildRadialChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const ui.Color(0xFFBDA206).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const ui.Color(0xFFBDA206).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.radar,
                  size: 20,
                  color: ui.Color(0xFFBDA206),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Citas por Día de la Semana - Este Mes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Gráfico
          FutureBuilder<Map<String, int>>(
            future: _dayOfWeekData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: ui.Color(0xFFBDA206))),
                );
              }
              
              if (!snapshot.hasData || snapshot.data!.values.every((v) => v == 0)) {
                return SizedBox(
                  height: 300,
                  child: Center(
                    child: Text(
                      'No hay datos para este mes',
                      style: TextStyle(
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              
              final data = snapshot.data!;
              final chartData = data.entries.map((e) => _ChartData(e.key, e.value)).toList();
              
              return SizedBox(
                height: 300,
                child: SfCircularChart(
                  legend: Legend(
                    isVisible: false,
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y citas',
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  series: <CircularSeries>[
                    RadialBarSeries<_ChartData, String>(
                      dataSource: chartData,
                      xValueMapper: (_ChartData data, _) => data.label,
                      yValueMapper: (_ChartData data, _) => data.value,
                      pointColorMapper: (_ChartData data, _) => const ui.Color(0xFFBDA206),
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      dataLabelMapper: (_ChartData data, _) => '${data.label}\n${data.value}',
                      cornerStyle: CornerStyle.bothCurve,
                      enableTooltip: true,
                      maximumValue: chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Helper: Obtener color por estado
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completadas': return const Color(0xFF4CAF50); // Verde
      case 'Confirmadas': return const Color(0xFF2196F3); // Azul
      case 'Pendientes': return const Color(0xFFFF9800); // Naranja
      case 'Canceladas': return const Color(0xFF9E9E9E); // Gris
      case 'Perdidas': return const Color(0xFFFF5722); // Rojo
      default: return const Color(0xFFBDA206); // Amarillo
    }
  }

  /// Helper: Obtener color por índice de servicio
  Color _getServiceColor(int index) {
    final colors = [
      const ui.Color(0xFFBDA206), // Amarillo
      const Color(0xFF4CAF50), // Verde
      const Color(0xFF2196F3), // Azul
      const Color(0xFF9C27B0), // Morado
      const Color(0xFFFF5722), // Rojo-naranja
    ];
    return colors[index % colors.length];
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

class NextAppointmentCard extends StatelessWidget {
  final String title;
  final Future<Map<String, dynamic>?> appointmentFuture;
  final IconData icon;
  final bool isDark;
  final AppLocalizations localizations;

  const NextAppointmentCard({
    super.key,
    required this.title,
    required this.appointmentFuture,
    required this.icon,
    required this.isDark,
    required this.localizations,
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
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 24,
                color: const ui.Color(0xFFBDA206),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: appointmentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(ui.Color(0xFFBDA206)),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                );
              }
              
              if (snapshot.data == null) {
                return const Text(
                  'Sin citas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ui.Color(0xFFBDA206),
                  ),
                );
              }
              
              final appointment = snapshot.data!;
              // Mostrar hora UTC (Opción 1)
              final startTime = DateTime.parse(appointment['start_time']).toUtc();
              final timeFormat = DateFormat('HH:mm');
              
              return Text(
                timeFormat.format(startTime),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ui.Color(0xFFBDA206),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RevenueCard extends StatelessWidget {
  final String title;
  final Future<double> revenueFuture;
  final IconData icon;
  final bool isDark;

  const RevenueCard({
    super.key,
    required this.title,
    required this.revenueFuture,
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
          FutureBuilder<double>(
            future: revenueFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  '...',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ui.Color(0xFFBDA206),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  '\$0',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ui.Color(0xFFBDA206),
                  ),
                );
              }
              final revenue = snapshot.data ?? 0.0;
              return Text(
                revenue >= 1000 
                     ? '\$${(revenue / 1000).toStringAsFixed(1)}K'
                    : '\$${revenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ui.Color(0xFFBDA206),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Falta la clase NotificationsBottomSheet que necesitas definir o importar
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: const Center(
        child: Text('Notificaciones'),
      ),
    );
  }
}

// Clase auxiliar para datos de gráficos
class _ChartData {
  _ChartData(this.label, this.value);
  final String label;
  final int value;
}