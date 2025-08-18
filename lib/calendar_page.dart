import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appbar.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import './integrations/appointments_service.dart';

// [------------- CONSTANTES DE ESTILO Y TEMAS --------------]
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const Color confirmedColor = Color(0xFF4CAF50);
const Color completeColor = Color(0xFF2196F3);
const Color inProgressColor = Color(0xFFFF9800);
const Color pendingColor = Color(0xFFFF5722);
const Color cancelledColor = Color(0xFF9E9E9E);
const Color postponedColor = Color(0xFF9C27B0); // Color morado para aplazadas
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
  bool _isLoading = false;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _appointments = [];
  LinkedHashMap<String, List<Map<String, dynamic>>> _groupedAppointments = LinkedHashMap();
  Set<DateTime> _datesWithAppointments = {};

  // [------------- INICIALIZACIÓN Y LIMPIEZA --------------]
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

  // [------------- OBTENCIÓN DE DATOS DEL USUARIO --------------]
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

  // [------------- CARGA Y AGRUPACIÓN DE CITAS DESDE SUPABASE --------------]
  Future<void> _fetchAppointments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      // Obtener citas del mes actual
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
      
      final appointments = await AppointmentsService.getFilteredAppointments(
        employeeId: user.id,
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _groupAndMarkAppointments();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error al cargar las citas: ${e.toString()}');
      }
    }
  }

  void _groupAndMarkAppointments() {
    LinkedHashMap<String, List<Map<String, dynamic>>> newGroupedAppointments = LinkedHashMap();
    Set<DateTime> newDatesWithAppointments = {};

    _appointments.sort((a, b) => DateTime.parse(a['start_time']).compareTo(DateTime.parse(b['start_time'])));

    for (var appointment in _appointments) {
      final appointmentDate = DateTime.parse(appointment['start_time']);
      final dateKey = DateFormat('dd/MM/yyyy').format(appointmentDate);
      
      newGroupedAppointments.putIfAbsent(dateKey, () => []).add(appointment);
      newDatesWithAppointments.add(DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day));
    }

    setState(() {
      _groupedAppointments = newGroupedAppointments;
      _datesWithAppointments = newDatesWithAppointments;
    });
  }

  // [------------- MÉTODO PARA OBTENER COLOR POR ESTADO --------------]
  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmada':
        return confirmedColor;
      case 'completa':
        return completeColor;
      case 'en_progreso':
        return inProgressColor;
      case 'pendiente':
        return pendingColor;
      case 'cancelada':
        return cancelledColor;
      case 'aplazada':
        return postponedColor;
      default:
        return primaryColor;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmada':
        return 'Confirmada';
      case 'completa':
        return 'Completada';
      case 'en_progreso':
        return 'En Progreso';
      case 'pendiente':
        return 'Pendiente';
      case 'cancelada':
        return 'Cancelada';
      case 'aplazada':
        return 'Aplazada';
      default:
        return 'Desconocido';
    }
  }

  // [------------- UTILIDADES PARA MENSAJES Y NAVEGACIÓN --------------]
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Método para manejar actualizaciones de citas - CORREGIDO
  Future<void> _handleAppointmentUpdate() async {
    // Refrescar los datos del calendario INMEDIATAMENTE
    await _fetchAppointments();
    
    // Forzar reconstrucción del widget completo
    if (mounted) {
      setState(() {
        // Esto fuerza una reconstrucción completa de toda la página
        _selectedDay = _selectedDay; // Trigger rebuild
      });
    }
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

  // [------------- MODAL DE DETALLES DE CITAS - MEJORADO --------------]
  void _showAppointmentDetails(DateTime selectedDate) {
    final dateKey = DateFormat('dd/MM/yyyy').format(selectedDate);
    final appointmentsForDate = _groupedAppointments[dateKey] ?? [];

    if (appointmentsForDate.isEmpty) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color.fromRGBO(15, 19, 21, 0.95) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDateHeaderComplete(selectedDate),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? textColor : Colors.black87,
                          ),
                        ),
                        Text(
                          '${appointmentsForDate.length} cita${appointmentsForDate.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? hintColor : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? textColor : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Lista de citas
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: appointmentsForDate.length,
                itemBuilder: (context, index) {
                  final appointment = appointmentsForDate[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < appointmentsForDate.length - 1 ? 16 : 24,
                    ),
                    child: AppointmentDetailCard(
                      key: ValueKey('appointment_${appointment['id']}_${appointment['status']}'),
                      appointment: appointment,
                      isDark: isDark,
                      getStatusColor: _getStatusColor,
                      getStatusText: _getStatusText,
                      onStatusChanged: () async {
                        // IMPORTANTE: Actualizar INMEDIATAMENTE la página principal
                        await _handleAppointmentUpdate().then((_) {
                          // Cerrar el modal después de que se actualice la página
                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            Navigator.of(context).pop();
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // CRÍTICO: Cuando el modal se cierre, actualizar la página principal
      _handleAppointmentUpdate();
    });
  }

  String _formatDateHeaderComplete(DateTime date) {
    final day = date.day;
    final month = _getMonthName(date.month);
    final weekday = _getWeekdayName(date.weekday);
    return '$weekday, $day de $month';
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    return weekdays[weekday - 1];
  }

  // [------------- NAVEGACIÓN DEL CALENDARIO --------------]
  void _goToPreviousMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    });
    _fetchAppointments();
  }

  void _goToNextMonth() {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    });
    _fetchAppointments();
  }

  // [------------- CONSTRUCCIÓN DEL LAYOUT PRINCIPAL --------------]
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
                  if (_isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/appointments').then((_) {
                    // Recargar citas cuando se regrese de crear una nueva
                    _fetchAppointments();
                  });
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

  // [------------- CONTENIDO PRINCIPAL DEL CALENDARIO --------------]
  Widget _buildMainContent(bool isDark, bool isWide) {
    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: primaryColor,
      child: SingleChildScrollView(
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
      ),
    );
  }

  // [------------- ENCABEZADO DEL CALENDARIO --------------]
  Widget _buildCalendarHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: isDark ? textColor : Colors.black87),
          onPressed: _goToPreviousMonth,
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
          onPressed: _goToNextMonth,
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

  // [------------- CUADRÍCULA DEL CALENDARIO CON INDICADORES DE ESTADO --------------]
  Widget _buildCalendarGrid(bool isDark) {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;

    final List<String> weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    return Column(
      children: [
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
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            double aspectRatio = screenWidth >= 800 ? 1.9 : 1.0;
            double spacing = screenWidth >= 800 ? 2.0 : 4.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: aspectRatio,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
              ),
              itemCount: daysInMonth + weekdayOfFirstDay,
              itemBuilder: (context, index) {
                if (index < weekdayOfFirstDay) {
                  return Container();
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

                // Obtener color dominante del día basado en las citas
                Color? dominantColor;
                final dateKey = DateFormat('dd/MM/yyyy').format(date);
                final appointmentsForDate = _groupedAppointments[dateKey] ?? [];
                final appointmentCount = appointmentsForDate.length;

                if (appointmentsForDate.isNotEmpty) {
                  // Priorizar citas aplazadas (morado)
                  if (appointmentsForDate.any((apt) => apt['status'] == 'aplazada')) {
                    dominantColor = postponedColor;
                  } else if (appointmentsForDate.any((apt) => apt['status'] == 'confirmada')) {
                    dominantColor = confirmedColor;
                  } else if (appointmentsForDate.any((apt) => apt['status'] == 'completa')) {
                    dominantColor = completeColor;
                  } else if (appointmentsForDate.any((apt) => apt['status'] == 'pendiente')) {
                    dominantColor = pendingColor;
                  } else {
                    dominantColor = primaryColor;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = date;
                    });
                    if (hasAppointment) {
                      _showAppointmentDetails(date);
                    }
                  },
                  child: AnimatedContainer(
                    duration: themeAnimationDuration,
                    decoration: BoxDecoration(
                      color: hasAppointment && dominantColor != null
                          ? dominantColor.withValues(alpha: 0.15)
                          : (isToday
                              ? (isDark ? Colors.grey[700] : Colors.grey[200])
                              : (isDark ? Colors.grey[800] : Colors.white)),
                      borderRadius: BorderRadius.circular(borderRadius / 2),
                      border: Border.all(
                        color: isSelected
                            ? (dominantColor ?? primaryColor)
                            : (hasAppointment && dominantColor != null
                                ? dominantColor.withValues(alpha: 0.4)
                                : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: hasAppointment && dominantColor != null
                                ? dominantColor
                                : (isDark ? textColor : Colors.black87),
                          ),
                        ),
                        if (hasAppointment && appointmentCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 16,
                              height: 16,
                              constraints: const BoxConstraints(minWidth: 16),
                              decoration: BoxDecoration(
                                color: dominantColor ?? primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '$appointmentCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // [------------- LISTA DE CITAS DEL MES CON ESTADOS MEJORADOS --------------]
  Widget _buildAppointmentsListHeader(bool isDark) {
    // Contar citas por estado para mostrar estadísticas
    final statusCounts = <String, int>{};
    for (final appointment in _appointments) {
      final status = appointment['status'] as String;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? textColor : Colors.black87,
              ),
              child: const Text('Citas del Mes'),
            ),
            const SizedBox(width: 12),
            if (_appointments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_appointments.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
          ],
        ),
        // Mostrar indicadores de estado si hay citas
        if (statusCounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: statusCounts.entries.map((entry) {
              final status = entry.key;
              final count = entry.value;
              final color = _getStatusColor(status);
              final text = _getStatusText(status);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
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
                    getStatusColor: _getStatusColor,
                    getStatusText: _getStatusText,
                    onTap: () {
                      final appointmentDate = DateTime.parse(appointment['start_time']);
                      _showAppointmentDetails(appointmentDate);
                    },
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

// [------------- COMPONENTE PARA ELEMENTOS DE LA LISTA DE CITAS MEJORADO --------------]
class AppointmentListItem extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;
  final VoidCallback? onTap;
  final Color Function(String) getStatusColor;
  final String Function(String) getStatusText;

  const AppointmentListItem({
    super.key,
    required this.appointment,
    required this.isDark,
    required this.getStatusColor,
    required this.getStatusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final endTime = DateTime.parse(appointment['end_time']);
    final status = appointment['status'] as String;
    final clientData = appointment['clients'] as Map<String, dynamic>?;
    final clientName = clientData?['name'] ?? 'Cliente sin nombre';

    final statusColor = getStatusColor(status);
    final statusText = getStatusText(status);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: themeAnimationDuration,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1,
          ),
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
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? textColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? hintColor : Colors.grey[600],
                    ),
                  ),
                  if (appointment['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        appointment['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? hintColor : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono especial para citas aplazadas
                  if (status == 'aplazada') ...[
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [------------- COMPONENTE PARA TARJETAS DE DETALLE DE CITAS - MEJORADO CON APLAZADAS --------------]
class AppointmentDetailCard extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;
  final VoidCallback? onStatusChanged;
  final Color Function(String) getStatusColor;
  final String Function(String) getStatusText;

  const AppointmentDetailCard({
    super.key,
    required this.appointment,
    required this.isDark,
    required this.getStatusColor,
    required this.getStatusText,
    this.onStatusChanged,
  });

  @override
  State<AppointmentDetailCard> createState() => _AppointmentDetailCardState();
}

class _AppointmentDetailCardState extends State<AppointmentDetailCard> {
  bool _isUpdating = false;

  Future<void> _updateAppointmentStatus(String newStatus) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      await AppointmentsService.updateAppointmentStatus(
        appointmentId: widget.appointment['id'],
        employeeId: user.id,
        newStatus: newStatus,
      );
      
      if (mounted) {
        // Actualizar el estado local inmediatamente
        setState(() {
          widget.appointment['status'] = newStatus;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado correctamente'),
            backgroundColor: successColor,
            duration: Duration(seconds: 1),
          ),
        );
        
        // Llamar al callback para actualizar la vista padre
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showStatusChangeDialog() {
    final currentStatus = widget.appointment['status'] as String;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color.fromRGBO(15, 19, 21, 0.95) : Colors.white,
        title: Text(
          'Cambiar Estado',
          style: TextStyle(
            color: widget.isDark ? textColor : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption('pendiente', 'Pendiente', currentStatus),
            _buildStatusOption('confirmada', 'Confirmada', currentStatus),
            _buildStatusOption('completa', 'Completada', currentStatus),
            _buildStatusOption('cancelada', 'Cancelada', currentStatus),
            _buildStatusOption('aplazada', 'Aplazada', currentStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String value, String label, String currentStatus) {
    final isSelected = value == currentStatus;
    final color = widget.getStatusColor(value);
    
    return ListTile(
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: isSelected 
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : (value == 'aplazada' ? Icon(Icons.schedule, size: 12, color: color) : null),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: widget.isDark ? textColor : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        if (value != currentStatus) {
          _updateAppointmentStatus(value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(widget.appointment['start_time']);
    final endTime = DateTime.parse(widget.appointment['end_time']);
    final status = widget.appointment['status'] as String;
    final clientData = widget.appointment['clients'] as Map<String, dynamic>?;
    final clientName = clientData?['name'] ?? 'Cliente sin nombre';
    final clientPhone = clientData?['phone'];
    final clientEmail = clientData?['email'];
    final description = widget.appointment['description'];
    final notes = widget.appointment['notes'];
    final price = widget.appointment['price'];
    final depositPaid = widget.appointment['deposit_paid'];

    final statusColor = widget.getStatusColor(status);
    final statusText = widget.getStatusText(status);

    final duration = endTime.difference(startTime);
    final durationText = '${duration.inHours}h ${duration.inMinutes % 60}min';

    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información principal
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  status == 'aplazada' ? Icons.schedule : Icons.person,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? textColor : Colors.black87,
                      ),
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)} ($durationText)',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDark ? hintColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isUpdating ? null : _showStatusChangeDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isUpdating)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      else ...[
                        if (status == 'aplazada') ...[
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                      if (!_isUpdating) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: statusColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Información de contacto
          if (clientPhone != null || clientEmail != null) ...[
            Row(
              children: [
                Icon(
                  Icons.contact_phone,
                  size: 18,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Contacto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (clientPhone != null)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'Teléfono: $clientPhone',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? hintColor : Colors.grey[600],
                  ),
                ),
              ),
            if (clientEmail != null)
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'Email: $clientEmail',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? hintColor : Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          
          // Descripción del servicio
          if (description != null && description.toString().isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 18,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Servicio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                description.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Información financiera - CORREGIDA PARA DECIMAL
          if (price != null) ...[
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 18,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Información Financiera',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Builder(
                builder: (context) {
                  // Convertir price y depositPaid a double de forma segura
                  double totalPrice = 0.0;
                  double deposit = 0.0;
                  
                  // Procesar precio total
                  if (price is String) {
                    totalPrice = double.tryParse(price) ?? 0.0;
                  } else if (price is num) {
                    totalPrice = price.toDouble();
                  }
                  
                  // Procesar adelanto
                  if (depositPaid != null) {
                    if (depositPaid is String) {
                      deposit = double.tryParse(depositPaid) ?? 0.0;
                    } else if (depositPaid is num) {
                      deposit = depositPaid.toDouble();
                    }
                  }
                  
                  final pending = totalPrice - deposit;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Precio total
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.grey[700] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '\$${totalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? textColor : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Adelanto
                      if (deposit > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Adelanto pagado:',
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark ? hintColor : Colors.grey[600],
                              ),
                            ),
                            Text(
                              '\$${deposit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: confirmedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      
                      // Pendiente o estado de pago
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            pending > 0 ? 'Pendiente:' : 'Estado:',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDark ? hintColor : Colors.grey[600],
                            ),
                          ),
                          if (pending > 0)
                            Text(
                              '\$${pending.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: pendingColor,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: confirmedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  deposit > 0 ? 'Pagado completo' : 'Sin adelanto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: deposit > 0 ? confirmedColor : pendingColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Notas adicionales
          if (notes != null && notes.toString().isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.note,
                  size: 18,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Notas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                notes.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// [------------- COMPONENTE PARA NOTIFICACIONES --------------]
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Notificaciones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'No hay notificaciones',
                style: TextStyle(
                  color: hintColor,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [------------- COMPONENTE PARA FONDO DIFUMINADO --------------]
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