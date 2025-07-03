import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import 'package:intl/intl.dart';
import 'dart:collection'; // For LinkedHashMap

// Constantes globales para la página de citas
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

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> with TickerProviderStateMixin {
  String? _userName;
  late Future<void> _loadUserData;
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  bool _isPopupOpen = false;
  String? _error;
  String? _successMessage;
  List<Map<String, dynamic>> _appointments = [];
  LinkedHashMap<String, List<Map<String, dynamic>>> _groupedAppointments = LinkedHashMap();
  List<Map<String, dynamic>> _filteredAppointments = [];
  String _selectedFilter = 'all'; // all, today, week, month
  String _selectedStatus = 'all'; // all, confirmed, in_progress, pending, cancelled
  late AnimationController _errorAnimationController;
  late AnimationController _successAnimationController;

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
    _searchCtrl.addListener(_filterAppointments);

    _fetchAppointments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // Simulando datos de citas para el diseño
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _appointments = _generateSampleAppointments();
          _filterAppointments(); // Call filter after fetching to populate _filteredAppointments and _groupedAppointments
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar las citas. Verifica tu conexión.');
      }
    }
  }

  List<Map<String, dynamic>> _generateSampleAppointments() {
    final now = DateTime.now();
    return [
      {
        'id': '1',
        'client_name': 'María González',
        'service': 'Tatuaje pequeño de mariposa en muñeca con muchos detalles y colores vibrantes',
        'start_time': DateTime(now.year, now.month, now.day, 9, 0).toIso8601String(),
        'duration': 120, // minutos
        'status': 'confirmed',
        'notes': 'Diseño de mariposa en muñeca, cliente prefiere colores pastel y un estilo delicado. Traer referencias.',
        'client_phone': '+1 234-567-8901',
        'client_email': 'maria@email.com',
      },
      {
        'id': '2',
        'client_name': 'Carlos Ruiz',
        'service': 'Retoque de tatuaje de brazo completo con sombreado y líneas finas',
        'start_time': DateTime(now.year, now.month, now.day, 11, 30).toIso8601String(),
        'duration': 60,
        'status': 'in_progress',
        'notes': 'Retoque de colores en brazo, específicamente en la zona del hombro. Cliente quiere un negro más intenso.',
        'client_phone': '+1 234-567-8902',
        'client_email': 'carlos@email.com',
      },
      {
        'id': '3',
        'client_name': 'Ana López',
        'service': 'Consulta de diseño para un tatuaje grande en la espalda con temática floral',
        'start_time': DateTime(now.year, now.month, now.day, 14, 30).toIso8601String(),
        'duration': 30,
        'status': 'pending',
        'notes': 'Primera consulta para tatuaje grande en la espalda. Cliente busca un diseño floral con elementos abstractos.',
        'client_phone': '+1 234-567-8903',
        'client_email': 'ana@email.com',
      },
      {
        'id': '4',
        'client_name': 'Luis Martín',
        'service': 'Tatuaje mediano de un lobo aullando en el antebrazo con estilo realista',
        'start_time': DateTime(now.year, now.month, now.day + 1, 10, 0).toIso8601String(),
        'duration': 180,
        'status': 'confirmed',
        'notes': 'Diseño geométrico en espalda, con líneas muy definidas y sombreado sutil. Confirmar tamaño final.',
        'client_phone': '+1 234-567-8904',
        'client_email': 'luis@email.com',
      },
      {
        'id': '5',
        'client_name': 'Sofia Herrera',
        'service': 'Tatuaje grande de un dragón oriental en la pierna con escamas detalladas',
        'start_time': DateTime(now.year, now.month, now.day - 1, 15, 0).toIso8601String(),
        'duration': 240,
        'status': 'cancelled',
        'notes': 'Cancelado por cliente debido a un viaje inesperado. Reagendar para el próximo mes.',
        'client_phone': '+1 234-567-8905',
        'client_email': 'sofia@email.com',
      },
      {
        'id': '6',
        'client_name': 'Juan Pérez',
        'service': 'Piercing en la oreja',
        'start_time': DateTime(now.year, now.month, now.day, 16, 0).toIso8601String(),
        'duration': 30,
        'status': 'confirmed',
        'notes': 'Piercing helix, cliente ya tiene la joya.',
        'client_phone': '+1 234-567-8906',
        'client_email': 'juan@email.com',
      },
      {
        'id': '7',
        'client_name': 'Laura Gómez',
        'service': 'Diseño de cover-up para tatuaje antiguo en el hombro',
        'start_time': DateTime(now.year, now.month, now.day + 2, 13, 0).toIso8601String(),
        'duration': 90,
        'status': 'pending',
        'notes': 'Cover-up de un tatuaje tribal. Cliente quiere algo floral y femenino.',
        'client_phone': '+1 234-567-8907',
        'client_email': 'laura@email.com',
      },
    ];
  }

  void _filterAppointments() {
    final query = _searchCtrl.text.toLowerCase();
    List<Map<String, dynamic>> tempFilteredList = _appointments.where((appointment) {
      final clientName = appointment['client_name']?.toString().toLowerCase() ?? '';
      final service = appointment['service']?.toString().toLowerCase() ?? '';
      final notes = appointment['notes']?.toString().toLowerCase() ?? '';
      
      final matchesSearch = clientName.contains(query) || 
                           service.contains(query) || 
                           notes.contains(query);
      
      final matchesStatus = _selectedStatus == 'all' || appointment['status'] == _selectedStatus;
      
      final appointmentDate = DateTime.parse(appointment['start_time']);
      final now = DateTime.now();
      bool matchesDateFilter = true;
      
      switch (_selectedFilter) {
        case 'today':
          matchesDateFilter = appointmentDate.year == now.year &&
                             appointmentDate.month == now.month &&
                             appointmentDate.day == now.day;
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          matchesDateFilter = appointmentDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                             appointmentDate.isBefore(weekEnd.add(const Duration(days: 1)));
          break;
        case 'month':
          matchesDateFilter = appointmentDate.year == now.year &&
                             appointmentDate.month == now.month;
          break;
      }
      
      return matchesSearch && matchesStatus && matchesDateFilter;
    }).toList();
    
    // Ordenar por fecha y hora
    tempFilteredList.sort((a, b) {
      final dateA = DateTime.parse(a['start_time']);
      final dateB = DateTime.parse(b['start_time']);
      return dateA.compareTo(dateB);
    });

    // Group by date
    LinkedHashMap<String, List<Map<String, dynamic>>> newGroupedAppointments = LinkedHashMap();
    for (var appointment in tempFilteredList) {
      final dateKey = DateFormat('dd/MM/yyyy').format(DateTime.parse(appointment['start_time']));
      if (!newGroupedAppointments.containsKey(dateKey)) {
        newGroupedAppointments[dateKey] = [];
      }
      newGroupedAppointments[dateKey]!.add(appointment);
    }

    setState(() {
      _filteredAppointments = tempFilteredList;
      _groupedAppointments = newGroupedAppointments;
    });
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _loading = false;
    });
    _errorAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _errorAnimationController.reverse();
          setState(() => _error = null);
        }
      });
    });
  }

  void _showSuccess(String message) {
    setState(() => _successMessage = message);
    _successAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _successAnimationController.reverse();
          setState(() => _successMessage = null);
        }
      });
    });
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _showError('Error al cerrar sesión.');
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

  void _openCreateAppointmentPopup() {
    setState(() => _isPopupOpen = true);
  }

  void _openEditAppointmentPopup(Map<String, dynamic> appointment) {
    setState(() => _isPopupOpen = true);
  }

  void _closePopup() {
    setState(() => _isPopupOpen = false);
  }

  void _viewAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appointment,
        isDark: Provider.of<ThemeProvider>(context, listen: false).isDark,
      ),
    );
  }

  void _deleteAppointment(String id) {
    // Placeholder for delete logic
    _showSuccess('Cita $id eliminada con éxito (simulado).');
    setState(() {
      _appointments.removeWhere((app) => app['id'] == id);
      _filterAppointments(); // Re-filter to update the list
    });
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
                title: 'Gestión de Citas',
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
                  // Popup centrado en el contenido principal
                  if (_isPopupOpen)
                    Positioned.fill(
                      left: isWide ? 280 : 0,
                      child: AppointmentPopup(
                        onClose: _closePopup,
                        isDark: isDark,
                      ),
                    ),
                  // Mensajes de error y éxito (centered)
                  if (_error != null)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(_errorAnimationController),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              margin: EdgeInsets.symmetric(horizontal: isWide ? 296 : 16),
                              decoration: BoxDecoration(
                                color: errorColor,
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_successMessage != null)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(_successAnimationController),
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              margin: EdgeInsets.symmetric(horizontal: isWide ? 296 : 16),
                              decoration: BoxDecoration(
                                color: successColor,
                                borderRadius: BorderRadius.circular(borderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildFiltersAndSearch(isDark),
                const SizedBox(height: 16),
                // Adjusted height for the list to be more flexible
                SizedBox(
                  height: isWide ? MediaQuery.of(context).size.height * 0.7 : MediaQuery.of(context).size.height * 0.6,
                  child: _buildAppointmentsList(isDark, isWide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? textColor : Colors.black87,
                ),
                child: const Text('Mis Citas'),
              ),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
                child: Text('${_filteredAppointments.length} de ${_appointments.length} citas mostradas'),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _loading ? null : _openCreateAppointmentPopup,
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text(
              'Nueva Cita',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch(bool isDark) {
    return Column(
      children: [
        // Barra de búsqueda
        AnimatedContainer(
          duration: themeAnimationDuration,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(color: isDark ? textColor : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Buscar citas por cliente, servicio o notas...',
              hintStyle: TextStyle(color: isDark ? hintColor : Colors.grey[600]),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? hintColor : Colors.grey[600],
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        _filterAppointments();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Filtros
        Row(
          children: [
            Expanded(
              child: _buildFilterChips(isDark),
            ),
            const SizedBox(width: 16),
            _buildAppointmentStats(isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filtros de fecha
          _buildFilterChip('Todos', 'all', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Hoy', 'today', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Esta Semana', 'week', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Este Mes', 'month', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 16),
          // Filtros de estado
          _buildStatusFilterChip('Todos', 'all', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Confirmadas', 'confirmed', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('En Proceso', 'in_progress', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
              _filterAppointments();
            });
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Pendientes', 'pending', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
              _filterAppointments();
            });
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String selectedValue, bool isDark, Function(String) onTap) {
    final isSelected = selectedValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: themeAnimationDuration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? primaryColor.withValues(alpha: 0.2)
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? primaryColor
                : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected 
                ? primaryColor
                : (isDark ? hintColor : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value, String selectedValue, bool isDark, Function(String) onTap) {
    final isSelected = selectedValue == value;
    Color chipColor = primaryColor;
    
    switch (value) {
      case 'confirmed':
        chipColor = confirmedColor;
        break;
      case 'in_progress':
        chipColor = inProgressColor;
        break;
      case 'pending':
        chipColor = pendingColor;
        break;
      case 'cancelled':
        chipColor = cancelledColor;
        break;
    }
    
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: themeAnimationDuration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? chipColor.withValues(alpha: 0.2)
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? chipColor
                : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected 
                ? chipColor
                : (isDark ? hintColor : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentStats(bool isDark) {
    final confirmedCount = _appointments.where((a) => a['status'] == 'confirmed').length;
    final inProgressCount = _appointments.where((a) => a['status'] == 'in_progress').length;
    final pendingCount = _appointments.where((a) => a['status'] == 'pending').length;
    
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatDot(confirmedColor, confirmedCount),
          const SizedBox(width: 12),
          _buildStatDot(inProgressColor, inProgressCount),
          const SizedBox(width: 12),
          _buildStatDot(pendingColor, pendingCount),
        ],
      ),
    );
  }

  Widget _buildStatDot(Color color, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList(bool isDark, bool isWide) {
    if (_loading && _appointments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_filteredAppointments.isEmpty) {
      String emptyMessage;
      String emptySubmessage;
      
      if (_searchCtrl.text.isNotEmpty) {
        emptyMessage = 'No se encontraron citas';
        emptySubmessage = 'Intenta con otros términos de búsqueda o revisa los filtros';
      } else if (_selectedFilter != 'all' || _selectedStatus != 'all') {
        emptyMessage = 'No hay citas con estos filtros';
        emptySubmessage = 'Cambia los filtros para ver más citas';
      } else {
        emptyMessage = 'No hay citas registradas';
        emptySubmessage = 'Agrega tu primera cita para comenzar';
      }
      
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
                child: Text(emptyMessage),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[500],
                ),
                child: Text(
                  emptySubmessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchAppointments,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dateKey = _groupedAppointments.keys.elementAt(index);
                  final appointmentsForDate = _groupedAppointments[dateKey]!;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: isDark ? hintColor : Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              dateKey,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? textColor : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      isWide
                          ? GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, // Two columns for wide screens
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.5, // Adjust as needed for card height
                              ),
                              itemCount: appointmentsForDate.length,
                              itemBuilder: (context, appIndex) {
                                final appointment = appointmentsForDate[appIndex];
                                return AnimatedAppearance(
                                  delay: appIndex * 50,
                                  child: AppointmentCard(
                                    appointment: appointment,
                                    isDark: isDark,
                                    onView: () => _viewAppointmentDetails(appointment),
                                    onEdit: () => _openEditAppointmentPopup(appointment),
                                    onDelete: () => _deleteAppointment(appointment['id']),
                                    isLoading: _loading,
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: appointmentsForDate.length,
                              itemBuilder: (context, appIndex) {
                                final appointment = appointmentsForDate[appIndex];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AnimatedAppearance(
                                    delay: appIndex * 50,
                                    child: AppointmentCard(
                                      appointment: appointment,
                                      isDark: isDark,
                                      onView: () => _viewAppointmentDetails(appointment),
                                      onEdit: () => _openEditAppointmentPopup(appointment),
                                      onDelete: () => _deleteAppointment(appointment['id']),
                                      isLoading: _loading,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                },
                childCount: _groupedAppointments.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLoading;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isDark,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final duration = appointment['duration'] as int;
    final status = appointment['status'] as String;
    final bool isWide = MediaQuery.of(context).size.width >= 800;

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

    // Dynamic background and shadow based on status
    final Color cardBgColor = isDark ? Colors.grey[800]! : Colors.white;
    final Color cardBorderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final Color shadowColor = isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: themeAnimationDuration,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: cardBorderColor,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isDark ? 6 : 4,
            offset: const Offset(0, 2),
          ),
          // Subtle gradient based on status for variety
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.05 : 0.03),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con hora, cliente y estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hora
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(startTime),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Text(
                        '${duration}min',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? hintColor : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Información del cliente
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['client_name'] ?? 'Cliente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textColor : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment['service'] ?? 'Servicio',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? hintColor : Colors.grey[700],
                        ),
                        maxLines: 2, // Added maxLines
                        overflow: TextOverflow.ellipsis, // Added overflow
                      ),
                      if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          appointment['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? hintColor : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Estado
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
            
            const SizedBox(height: 16),
            
            // Información adicional y botones
            Row(
              children: [
                // Fecha
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700]?.withValues(alpha: 0.3) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? hintColor : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Botones de acción
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Delete Button (replaces view button)
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1), // Use error color for delete
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: errorColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete, size: isWide ? 20 : 18), // Trash icon
                        color: errorColor,
                        onPressed: isLoading ? null : onDelete, // Call onDelete
                        tooltip: 'Eliminar cita',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit, size: isWide ? 20 : 18),
                        color: primaryColor,
                        onPressed: isLoading ? null : onEdit,
                        tooltip: 'Editar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentPopup extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDark;

  const AppointmentPopup({
    super.key,
    required this.onClose,
    required this.isDark,
  });

  @override
  State<AppointmentPopup> createState() => _AppointmentPopupState();
}

class _AppointmentPopupState extends State<AppointmentPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedDuration = 60;
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _serviceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: (0.5 * _opacityAnimation.value).clamp(0.0, 1.0)),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.95,
                    constraints: const BoxConstraints(maxWidth: 600),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              _buildClientSection(),
                              const SizedBox(height: 20),
                              _buildAppointmentSection(),
                              const SizedBox(height: 24),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.event_available,
            color: Colors.black,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nueva Cita',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? textColor : Colors.black87,
                ),
              ),
              Text(
                'Programa una nueva cita con el cliente',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _closeWithAnimation,
            color: widget.isDark ? textColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildClientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Información del Cliente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? textColor : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _clientNameCtrl,
          style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
          decoration: _buildInputDecoration('Nombre completo *', Icons.person_outline),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El nombre es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _clientPhoneCtrl,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                decoration: _buildInputDecoration('Teléfono', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value)) {
                    return 'Ingresa un número de teléfono válido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _clientEmailCtrl,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                decoration: _buildInputDecoration('Email', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Ingresa un email válido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_available,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Detalles de la Cita',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? textColor : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serviceCtrl,
          style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
          decoration: _buildInputDecoration('Servicio *', Icons.work_outline),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El servicio es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: TextStyle(
                          color: widget.isDark ? textColor : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (time != null) {
                    setState(() => _selectedTime = time);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime.format(context),
                        style: TextStyle(
                          color: widget.isDark ? textColor : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible( // Use Flexible to control width
              flex: 1,
              child: DropdownButtonFormField<int>(
                value: _selectedDuration,
                decoration: _buildInputDecoration('Duración', Icons.timer_outlined, isDropdown: true),
                dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                items: [30, 60, 90, 120, 180, 240].map((duration) {
                  return DropdownMenuItem(
                    value: duration,
                    child: Text('$duration min'), // Shorter text
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDuration = value!),
              ),
            ),
            const SizedBox(width: 16),
            Flexible( // Use Flexible to control width
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: _buildInputDecoration('Estado', Icons.flag_outlined, isDropdown: true),
                dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                items: [
                  const DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                  const DropdownMenuItem(value: 'confirmed', child: Text('Confirmada')),
                  const DropdownMenuItem(value: 'in_progress', child: Text('En Proceso')),
                ],
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesCtrl,
          style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
          decoration: _buildInputDecoration('Notas adicionales', Icons.note_outlined),
          maxLines: 3,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isDropdown = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: widget.isDark ? hintColor : Colors.grey[600],
        fontSize: 14,
      ),
      prefixIcon: isDropdown ? null : Container( // Remove prefix icon for dropdowns
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: primaryColor,
          size: 20,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder( // Added error border style
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder( // Added focused error border style
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      filled: true,
      fillColor: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextButton(
            onPressed: _closeWithAnimation,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close,
                  size: 18,
                  color: widget.isDark ? textColor : Colors.black87,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cancelar',
                  style: TextStyle(
                    color: widget.isDark ? textColor : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Aquí iría la lógica para guardar la cita
                _closeWithAnimation();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.save,
                  color: Colors.black,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Guardar Cita',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AppointmentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;

  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final duration = appointment['duration'] as int;
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

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.event_available,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalles de la Cita',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? textColor : Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
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
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? textColor : Colors.black87,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Información de la cita
              _buildDetailRow(
                Icons.person,
                'Cliente',
                appointment['client_name'] ?? 'N/A',
                isDark,
              ),
              _buildDetailRow(
                Icons.work,
                'Servicio',
                appointment['service'] ?? 'N/A',
                isDark,
              ),
              _buildDetailRow(
                Icons.calendar_today,
                'Fecha',
                DateFormat('EEEE, dd MMMM yyyy', 'es').format(startTime),
                isDark,
              ),
              _buildDetailRow(
                Icons.access_time,
                'Hora',
                DateFormat('HH:mm').format(startTime),
                isDark,
              ),
              _buildDetailRow(
                Icons.timer,
                'Duración',
                '$duration minutos',
                isDark,
              ),
              if (appointment['client_phone'] != null && appointment['client_phone'].isNotEmpty)
                _buildDetailRow(
                  Icons.phone,
                  'Teléfono',
                  appointment['client_phone'],
                  isDark,
                ),
              if (appointment['client_email'] != null && appointment['client_email'].isNotEmpty)
                _buildDetailRow(
                  Icons.email,
                  'Email',
                  appointment['client_email'],
                  isDark,
                ),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                _buildDetailRow(
                  Icons.note,
                  'Notas',
                  appointment['notes'],
                  isDark,
                ),
              
              const SizedBox(height: 24),
              
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Aquí se abriría el popup de edición
                    },
                    icon: const Icon(Icons.edit, color: Colors.black),
                    label: const Text(
                      'Editar',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? hintColor : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? textColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedAppearance extends StatefulWidget {
  final Widget child;
  final int delay;

  const AnimatedAppearance({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<AnimatedAppearance> createState() => _AnimatedAppearanceState();
}

class _AnimatedAppearanceState extends State<AnimatedAppearance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
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
