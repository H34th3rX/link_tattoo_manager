import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appbar.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';

// Reusing constants from appointments_page.dart for consistency
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const Color confirmedColor = Color(0xFF4CAF50);
const Color inProgressColor = Color(0xFFFF9800);
const Color pendingColor = Color(0xFFFF5722);
const Color cancelledColor = Color(0xFF9E9E9E);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin {
  String? _userName;
  late Future<void> _loadUserData;
  late AnimationController _errorAnimationController;
  late AnimationController _successAnimationController;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];
  LinkedHashMap<String, List<Map<String, dynamic>>> _groupedAppointments = LinkedHashMap();
  Set<DateTime> _datesWithAppointments = {};

  @override
  void initState() {
    super.initState();
    _loadUserData = _fetchUserData();
    _errorAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
    _fetchAppointments();
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
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
    } catch (e) {
      _showError('Error al cargar datos del usuario');
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      // Simulate fetching data
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _appointments = _generateSampleAppointments();
          _groupAndMarkAppointments();
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar las citas. Verifica tu conexión.');
      }
    }
  }

  void _groupAndMarkAppointments() {
    LinkedHashMap<String, List<Map<String, dynamic>>> newGroupedAppointments = LinkedHashMap();
    Set<DateTime> newDatesWithAppointments = {};

    // Sort appointments by date and time
    _appointments.sort((a, b) {
      final dateA = DateTime.parse(a['start_time']);
      final dateB = DateTime.parse(b['start_time']);
      return dateA.compareTo(dateB);
    });

    for (var appointment in _appointments) {
      final appointmentDate = DateTime.parse(appointment['start_time']);
      final dateKey = DateFormat('dd/MM/yyyy').format(appointmentDate);
      
      if (!newGroupedAppointments.containsKey(dateKey)) {
        newGroupedAppointments[dateKey] = [];
      }
      newGroupedAppointments[dateKey]!.add(appointment);
      newDatesWithAppointments.add(DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day));
    }

    setState(() {
      _groupedAppointments = newGroupedAppointments;
      _datesWithAppointments = newDatesWithAppointments;
    });
  }

  List<Map<String, dynamic>> _generateSampleAppointments() {
    final now = DateTime.now();
    return [
      {
        'id': '1',
        'client_name': 'María González',
        'service': 'Tatuaje pequeño',
        'start_time': DateTime(now.year, now.month, 15, 14, 0).toIso8601String(),
        'duration': 120,
        'status': 'confirmed',
        'notes': 'Diseño de mariposa en muñeca',
      },
      {
        'id': '2',
        'client_name': 'Carlos Ruiz',
        'service': 'Retoque tatuaje',
        'start_time': DateTime(now.year, now.month, 22, 10, 0).toIso8601String(),
        'duration': 60,
        'status': 'confirmed',
        'notes': 'Retoque de colores en brazo',
      },
      {
        'id': '3',
        'client_name': 'Ana López',
        'service': 'Consulta diseño',
        'start_time': DateTime(now.year, now.month, 28, 16, 0).toIso8601String(),
        'duration': 30,
        'status': 'confirmed',
        'notes': 'Primera consulta para tatuaje grande',
      },
      {
        'id': '4',
        'client_name': 'Luis Martín',
        'service': 'Tatuaje mediano',
        'start_time': DateTime(now.year, now.month, 3, 10, 0).toIso8601String(),
        'duration': 180,
        'status': 'confirmed',
        'notes': 'Diseño geométrico en espalda',
      },
      {
        'id': '5',
        'client_name': 'Sofia Herrera',
        'service': 'Tatuaje grande',
        'start_time': DateTime(now.year, now.month, 2, 15, 0).toIso8601String(),
        'duration': 240,
        'status': 'cancelled',
        'notes': 'Cancelado por cliente',
      },
    ];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _showError('Error al cerrar sesión');
    }
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;
    final bool isDark = themeProvider.isDark;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Scaffold(
              backgroundColor: isDark ? backgroundColor : Colors.grey[100],
              appBar: CustomAppBar(
                title: 'Calendario',
                onNotificationPressed: _showNotifications,
                isWide: isWide,
              ),
              drawer: isWide
                  ? null
                  : Drawer(
                      child: _userName != null
                          ? NavPanel(
                              user: user,
                              onLogout: _logout,
                              userName: _userName!,
                            )
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
                                      onLogout: _logout,
                                      userName: _userName!,
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _buildMainContent(isDark, isWide),
                            ),
                          ],
                        )
                      : _buildMainContent(isDark, isWide),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/appointments/new');
                },
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainContent(bool isDark, bool isWide) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCalendarHeader(isDark),
                const SizedBox(height: 16),
                _buildCalendarGrid(isDark),
                const SizedBox(height: 32),
                _buildAppointmentsListHeader(isDark),
                const SizedBox(height: 16),
                _buildAppointmentsList(isDark, isWide),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: isDark ? textColor : Colors.black87),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
            });
          },
        ),
        AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? textColor : Colors.black87,
          ),
          child: Text('${_getMonthName(_focusedDay.month)} ${_focusedDay.year}'),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: isDark ? textColor : Colors.black87),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
            });
          },
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month - 1];
  }

  Widget _buildCalendarGrid(bool isDark) {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday; // Adjust for Sunday = 0

    final List<String> weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? hintColor : Colors.grey[600],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar days
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: daysInMonth + weekdayOfFirstDay,
          itemBuilder: (context, index) {
            if (index < weekdayOfFirstDay) {
              return Container(); // Empty cells for days before the 1st
            }
            final day = index - weekdayOfFirstDay + 1;
            final date = DateTime(_focusedDay.year, _focusedDay.month, day);
            final isToday = date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;
            final hasAppointment = _datesWithAppointments.contains(date);
            final isSelected = date.year == _selectedDay.year &&
                               date.month == _selectedDay.month &&
                               date.day == _selectedDay.day;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDay = date;
                  // Optionally filter appointments for selected day
                });
              },
              child: AnimatedContainer(
                duration: themeAnimationDuration,
                decoration: BoxDecoration(
                  color: hasAppointment
                      ? primaryColor.withValues(alpha: 0.2)
                      : (isToday
                          ? (isDark ? Colors.grey[700] : Colors.grey[200])
                          : (isDark ? Colors.grey[800] : Colors.white)),
                  borderRadius: BorderRadius.circular(borderRadius / 2),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: hasAppointment
                            ? primaryColor
                            : (isDark ? textColor : Colors.black87),
                      ),
                    ),
                    if (hasAppointment)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red, // Red dot for appointments
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppointmentsListHeader(bool isDark) {
    return AnimatedDefaultTextStyle(
      duration: themeAnimationDuration,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: isDark ? textColor : Colors.black87,
      ),
      child: const Text('Citas del Mes'),
    );
  }

  Widget _buildAppointmentsList(bool isDark, bool isWide) {
    if (_groupedAppointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 64,
                color: isDark ? hintColor : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
                child: const Text('No hay citas registradas para este mes'),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[500],
                ),
                child: const Text(
                  'Agrega tu primera cita para comenzar',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _groupedAppointments.keys.length,
      itemBuilder: (context, index) {
        final dateKey = _groupedAppointments.keys.elementAt(index);
        final appointmentsForDate = _groupedAppointments[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _formatDateHeader(DateTime.parse(appointmentsForDate.first['start_time'])),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appointmentsForDate.length,
              itemBuilder: (context, appIndex) {
                final appointment = appointmentsForDate[appIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppointmentListItem(
                    appointment: appointment,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final day = date.day;
    final month = _getMonthName(date.month);
    return '$day de $month';
  }
}

class AppointmentListItem extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;

  const AppointmentListItem({
    super.key,
    required this.appointment,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final status = appointment['status'] as String;

    Color statusColor = primaryColor;
    String statusText = '';
    
    switch (status) {
      case 'confirmed':
        statusColor = confirmedColor;
        statusText = 'Confirmada';
        break;
      case 'in_progress':
        statusColor = inProgressColor;
        statusText = 'En Proceso';
        break;
      case 'pending':
        statusColor = pendingColor;
        statusText = 'Pendiente';
        break;
      case 'cancelled':
        statusColor = cancelledColor;
        statusText = 'Cancelada';
        break;
    }

    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment['client_name'] ?? 'Cliente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? textColor : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('HH:mm').format(startTime)} - ${appointment['service'] ?? 'Servicio'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? hintColor : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BlurredBackground extends StatelessWidget {
  final bool isDark;

  const BlurredBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/logo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: themeAnimationDuration,
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.7)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
