// ignore_for_file: use_build_context_synchronously

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import 'package:intl/intl.dart';
import 'dart:collection';
import './integrations/clients_service.dart';
import './integrations/appointments_service.dart';
import './services/notification_scheduler.dart';
import './services/services_service.dart';

//[------------- CONSTANTES GLOBALES DE ESTILO --------------]
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const Color confirmedColor = Color(0xFF4CAF50);
const Color completeColor = Color(0xFF2196F3);
const Color inProgressColor = Color(0xFFFF9800);
const Color pendingColor = ui.Color.fromARGB(255, 171, 209, 36);
const Color cancelledColor = Color(0xFF9E9E9E);
const Color postponedColor = Color(0xFF9C27B0);
const Color missedColor = Color(0xFFFF5722); 
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key, Map<String, dynamic>? arguments});

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
  String _selectedStatus = 'all'; // all, confirmada, completa, pendiente, cancelada
  late AnimationController _errorAnimationController;
  late AnimationController _successAnimationController;

  // Datos para el modo de edición o precarga de nueva cita
  Map<String, dynamic>? _appointmentToEdit;
  Map<String, dynamic>? _initialClientForNewAppointment;
  bool _isPostponedAppointment = false; // Flag para identificar citas aplazadas
  // Nuevo: información para el proceso de aplazamiento
  Map<String, dynamic>? _originalAppointmentToPostpone;

  // Flag para asegurar que el popup se abra solo una vez al navegar
  bool _hasProcessedInitialPopup = false;

  //[------------- MÉTODOS DE CICLO DE VIDA DEL WIDGET --------------]
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Abre el popup de nueva cita si se navega con el argumento `openNewAppointmentPopup`
    if (!_hasProcessedInitialPopup) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        if (args['openNewAppointmentPopup'] == true) {
          _hasProcessedInitialPopup = true;
          _initialClientForNewAppointment = args['initialClientData'];
          // Programa la apertura del popup después de que el frame actual se haya construido
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openCreateAppointmentPopup(clientData: _initialClientForNewAppointment);
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  //[------------- MÉTODOS DE DATOS Y LÓGICA DE NEGOCIO --------------]
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
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      
      List<Map<String, dynamic>> appointments;
      
      // Aplicar filtros de fecha y estado
      if (_selectedFilter != 'all' || _selectedStatus != 'all') {
        DateTime? startDate;
        DateTime? endDate;
        final now = DateTime.now();
        
        switch (_selectedFilter) {
          case 'today':
            startDate = DateTime(now.year, now.month, now.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
            break;
          case 'week':
            startDate = now.subtract(Duration(days: now.weekday - 1));
            endDate = startDate.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
            break;
          case 'month':
            startDate = DateTime(now.year, now.month, 1);
            endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            break;
        }
        
        appointments = await AppointmentsService.getFilteredAppointments(
          employeeId: user.id,
          startDate: startDate,
          endDate: endDate,
          status: _selectedStatus,
        );
      } else {
        appointments = await AppointmentsService.getAppointments(user.id);
      }

      if (mounted) {
        setState(() {
          _appointments = appointments;
          _filterAppointments();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _showError('Error al cargar las citas: ${e.toString()}');
      }
    }
  }

  void _filterAppointments() {
    final query = _searchCtrl.text.toLowerCase();
    List<Map<String, dynamic>> tempFilteredList = _appointments.where((appointment) {
      final clientName = _getClientName(appointment).toLowerCase();
      final serviceName = _getServiceName(appointment).toLowerCase();
      final notes = (appointment['notes']?.toString() ?? '').toLowerCase();

      final matchesSearch = clientName.contains(query) ||
                          serviceName.contains(query) ||  // CAMBIO
                          notes.contains(query);

      return matchesSearch;
    }).toList();

    // CAMBIO: Ordenar por fecha de creación descendente (más reciente primero)
    tempFilteredList.sort((a, b) {
      final dateA = DateTime.parse(a['created_at'] ?? a['start_time']);
      final dateB = DateTime.parse(b['created_at'] ?? b['start_time']);
      return dateB.compareTo(dateA); // Orden descendente
    });

    // Agrupar por fecha
   LinkedHashMap<String, List<Map<String, dynamic>>> newGroupedAppointments = LinkedHashMap();
    for (var appointment in tempFilteredList) {
      final dateKey = DateFormat('dd/MM/yyyy').format(DateTime.parse(appointment['start_time']));
      if (!newGroupedAppointments.containsKey(dateKey)) {
        newGroupedAppointments[dateKey] = [];
      }
      newGroupedAppointments[dateKey]!.add(appointment);
    }

    newGroupedAppointments.forEach((key, appointments) {
      appointments.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] ?? a['start_time']);
        final dateB = DateTime.parse(b['created_at'] ?? b['start_time']);
        return dateB.compareTo(dateA);
      });
    });

    setState(() {
      _filteredAppointments = tempFilteredList;
      _groupedAppointments = newGroupedAppointments;
    });
  }

  String _getClientName(Map<String, dynamic> appointment) {
    final clientsData = appointment['clients'];
    if (clientsData is List && clientsData.isNotEmpty) {
      return clientsData[0]['name']?.toString() ?? 'Cliente Desconocido';
    } else if (clientsData is Map) {
      return clientsData['name']?.toString() ?? 'Cliente Desconocido';
    }
    return 'Cliente Desconocido';
  }
  
  String _getServiceName(Map<String, dynamic> appointment) {
    final services = appointment['services'];
    if (services != null && services is Map) {
      return services['name'] as String? ?? 'Sin servicio';
    }
    return 'Sin servicio';
  }

  int _calculateDuration(Map<String, dynamic> appointment) {
    try {
      final startTime = DateTime.parse(appointment['start_time']);
      final endTime = DateTime.parse(appointment['end_time']);
      return endTime.difference(startTime).inMinutes;
    } catch (e) {
      return 60; // Valor por defecto
    }
  }

  void _showError(String message) {
    // Verificar mounted before de usar setState
    if (!mounted) return;
    
    setState(() {
      _error = message;
    });
    _errorAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _errorAnimationController.reverse();
          setState(() => _error = null);
        }
      });
    });
  }

  void _showSuccess(String message) {
    // Verificar mounted before de usar setState y ScaffoldMessenger
    if (!mounted) return;
    
    setState(() => _successMessage = message);
    _successAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
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

  //[------------- MÉTODOS DE GESTIÓN DE POPUPS Y CITAS --------------]
  void _openCreateAppointmentPopup({Map<String, dynamic>? clientData, bool isPostponed = false}) {
    setState(() {
      _appointmentToEdit = null;
      _initialClientForNewAppointment = clientData;
      _isPostponedAppointment = isPostponed;
      _isPopupOpen = true;
    });
  }

  void _openEditAppointmentPopup(Map<String, dynamic> appointment) {
    setState(() {
      _appointmentToEdit = appointment;
      _initialClientForNewAppointment = null;
      _isPostponedAppointment = false;
      _originalAppointmentToPostpone = null; // Limpiar cualquier referencia de aplazamiento
      _isPopupOpen = true;
    });
  }

  void _closePopup() {
    if (mounted) {
      setState(() {
        _isPopupOpen = false;
        _appointmentToEdit = null;
        _initialClientForNewAppointment = null;
        _isPostponedAppointment = false;
        _originalAppointmentToPostpone = null; // Limpiar referencia de aplazamiento
      });
    }
  }

  void _viewAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appointment,
        isDark: Provider.of<ThemeProvider>(context, listen: false).isDark,
        onEdit: () {
          Navigator.of(context).pop();
          _openEditAppointmentPopup(appointment);
        },
      ),
    );
  }

  Future<void> _deleteAppointment(String id) async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      if (!mounted) return;
      // Mostrar diálogo de confirmación
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Provider.of<ThemeProvider>(context).isDark 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
          title: Text(
            'Confirmar eliminación',
            style: TextStyle(
              color: Provider.of<ThemeProvider>(context).isDark ? textColor : Colors.black87,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres eliminar esta cita? Esta acción no se puede deshacer.',
            style: TextStyle(
              color: Provider.of<ThemeProvider>(context).isDark ? hintColor : Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDark ? textColor : Colors.black87,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await AppointmentsService.deleteAppointment(id, user.id);
        _showSuccess('Cita eliminada exitosamente');
        _fetchAppointments(); // Recargar la lista
      }
    } catch (e) {
      _showError('Error al eliminar la cita: ${e.toString()}');
    }
  }

  // Método mejorado para aplazar citas - ahora no marca inmediatamente como aplazada
  Future<void> _postponeAppointment(Map<String, dynamic> appointment) async {
    try {
      // Mostrar diálogo de confirmación
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Provider.of<ThemeProvider>(context).isDark 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
          title: Text(
            'Aplazar Cita',
            style: TextStyle(
              color: Provider.of<ThemeProvider>(context).isDark ? textColor : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Deseas aplazar esta cita?',
                style: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDark ? textColor : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Podrás programar una nueva fecha con el mismo cliente. La cita actual se marcará como aplazada solo si confirmas la nueva cita.',
                style: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDark ? hintColor : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Provider.of<ThemeProvider>(context).isDark ? textColor : Colors.black87,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: postponedColor,
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Preparar datos del cliente para la nueva cita
        final clientsData = appointment['clients'];
        Map<String, dynamic>? clientData;
        
        if (clientsData is List && clientsData.isNotEmpty) {
          clientData = {
            'id': clientsData[0]['id'],
            'name': clientsData[0]['name'],
            'phone': clientsData[0]['phone'],
            'email': clientsData[0]['email'],
          };
        } else if (clientsData is Map) {
          clientData = {
            'id': clientsData['id'],
            'name': clientsData['name'],
            'phone': clientsData['phone'],
            'email': clientsData['email'],
          };
        }

        // Guardar referencia de la cita original para aplazarla después
        setState(() {
          _originalAppointmentToPostpone = appointment;
        });

        // Abrir popup para nueva cita con datos del cliente bloqueados
        if (clientData != null) {
          _openCreateAppointmentPopup(clientData: clientData, isPostponed: true);
        }
      }
    } catch (e) {
      _showError('Error al iniciar el proceso de aplazamiento: ${e.toString()}');
    }
  }

  Future<void> _onAppointmentSaved() async {
    try {
      // Si es una cita de reemplazo (aplazamiento), marcar la original como aplazada
      if (_originalAppointmentToPostpone != null) {
        final user = Supabase.instance.client.auth.currentUser!;
        
        await AppointmentsService.postponeAppointment(
          appointmentId: _originalAppointmentToPostpone!['id'],
          employeeId: user.id,
        );
        
        _showSuccess('Cita original aplazada y nueva cita creada exitosamente');
      } else {
        _showSuccess('Cita guardada exitosamente');
      }
    } catch (e) {
      _showError('Error al finalizar el proceso: ${e.toString()}');
    } finally {
      _closePopup(); 
      await Future.delayed(const Duration(milliseconds: 100)); 
      if (mounted) {
        await _fetchAppointments(); 
      }
    }
  }

  // Método para cancelar el aplazamiento
  void _onAppointmentCancelled() {
    setState(() {
      _originalAppointmentToPostpone = null; 
    });
    _closePopup();
  }

  //[------------- CONSTRUCCIÓN DE LA INTERFAZ DE USUARIO --------------]
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
                        onClose: _onAppointmentCancelled,
                        isDark: isDark,
                        employeeId: user.id,
                        initialAppointment: _appointmentToEdit,
                        initialClientData: _initialClientForNewAppointment,
                        isPostponedAppointment: _isPostponedAppointment,
                        onSaved: _onAppointmentSaved,
                        onServicesUpdated: () async {  
                          if (mounted) {
                            await _fetchAppointments();
                          }
                        } 
                      ),
                    ),
                  // Mensajes de error y éxito
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
              horizontal: isWide ? 24 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                _buildFiltersAndSearch(isDark),
                const SizedBox(height: 16),
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
            onPressed: _isPopupOpen ? null : _openCreateAppointmentPopup,
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

        _buildFilterChips(isDark),
        
        const SizedBox(height: 12),
        
        _buildAppointmentStats(isDark),
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
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Hoy', 'today', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Esta Semana', 'week', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildFilterChip('Este Mes', 'month', _selectedFilter, isDark, (value) {
            setState(() {
              _selectedFilter = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 16),
          // Filtros de estado
          _buildStatusFilterChip('Todos', 'all', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Confirmadas', 'confirmada', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Completadas', 'completa', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Pendientes', 'pendiente', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Canceladas', 'cancelada', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Aplazadas', 'aplazada', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
          }),
          const SizedBox(width: 8),
          _buildStatusFilterChip('Perdidas', 'perdida', _selectedStatus, isDark, (value) {
            setState(() {
              _selectedStatus = value;
            });
            _fetchAppointments();
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
      case 'confirmada':
        chipColor = confirmedColor;
        break;
      case 'completa':
        chipColor = completeColor;
        break;
      case 'pendiente':
        chipColor = pendingColor;
        break;
      case 'cancelada':
        chipColor = cancelledColor;
        break;
      case 'aplazada':
        chipColor = postponedColor;
        break;
      case 'perdida':
        chipColor = missedColor;
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
  final pendingCount = _appointments.where((a) => a['status'] == 'pendiente').length;
  final confirmedCount = _appointments.where((a) => a['status'] == 'confirmada').length;
  final completeCount = _appointments.where((a) => a['status'] == 'completa').length;
  final canceledCount = _appointments.where((a) => a['status'] == 'cancelada').length;
  final postponedCount = _appointments.where((a) => a['status'] == 'aplazada').length;
  final missedCount = _appointments.where((a) => a['status'] == 'perdida').length;

  // Determinar color y contador según filtro activo
  Color activeColor = isDark ? Colors.grey[800]! : Colors.white;
  int? highlightCount;
  
  if (_selectedStatus != 'all') {
    switch (_selectedStatus) {
      case 'pendiente':
        activeColor = pendingColor;
        highlightCount = pendingCount;
        break;
      case 'confirmada':
        activeColor = confirmedColor;
        highlightCount = confirmedCount;
        break;
      case 'completa':
        activeColor = completeColor;
        highlightCount = completeCount;
        break;
      case 'cancelada':
        activeColor = cancelledColor;
        highlightCount = canceledCount;
        break;
      case 'aplazada':
        activeColor = postponedColor;
        highlightCount = postponedCount;
        break;
      case 'perdida':
        activeColor = missedColor;
        highlightCount = missedCount;
        break;
    }
  }

  final bool isFiltered = _selectedStatus != 'all';

  return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
    height: 64,
    padding: const EdgeInsets.all(16), 
    decoration: BoxDecoration(
      color: isFiltered ? activeColor.withValues(alpha: 0.15) : (isDark ? Colors.grey[800] : Colors.white),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFiltered ? activeColor : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
        width: isFiltered ? 2 : 1,
      ),
    ),
    child: isFiltered
        ? Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_selectedStatus),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.5 + (value * 0.5),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Text(
                      '$highlightCount',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(pendingColor, pendingCount),
              _buildStatItem(confirmedColor, confirmedCount),
              _buildStatItem(completeColor, completeCount),
              _buildStatItem(cancelledColor, canceledCount),
              _buildStatItem(postponedColor, postponedCount),
              _buildStatItem(missedColor, missedCount),
            ],
          ),
  );
}

  Widget _buildStatItem(Color color, int count) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '$count',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
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
                      AnimatedDateSection(
                        dateText: dateKey,
                        isDark: isDark,
                        index: index, // Pass the section index for staggered animation
                      ),
                      isWide
                          ? GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.5,
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
                                    onPostpone: () => _postponeAppointment(appointment),
                                    isLoading: _loading,
                                    getClientName: _getClientName,
                                    calculateDuration: _calculateDuration,
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
                                      onPostpone: () => _postponeAppointment(appointment),
                                      isLoading: _loading,
                                      getClientName: _getClientName,
                                      calculateDuration: _calculateDuration,
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

class AnimatedDateSection extends StatefulWidget {
  final String dateText;
  final bool isDark;
  final int index;

  const AnimatedDateSection({
    super.key,
    required this.dateText,
    required this.isDark,
    required this.index,
  });

  @override
  State<AnimatedDateSection> createState() => _AnimatedDateSectionState();
}

class _AnimatedDateSectionState extends State<AnimatedDateSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600 + (widget.index * 100)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
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
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [Colors.grey[800]!.withValues(alpha: 0.3), Colors.grey[700]!.withValues(alpha: 0.1)]
                  : [primaryColor.withValues(alpha: 0.1), primaryColor.withValues(alpha: 0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.grey[600]!.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Contenido centrado con espaciado
              Expanded(
                child: Center(
                  child: Text(
                    widget.dateText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? textColor : Colors.grey[800],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Barra derecha (simétrica a la izquierda)
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//[------------- WIDGET: AppointmentCard (Tarjeta de Cita) --------------]
class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPostpone;
  final bool isLoading;
  final String Function(Map<String, dynamic>) getClientName;
  final int Function(Map<String, dynamic>) calculateDuration;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isDark,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPostpone,
    required this.isLoading,
    required this.getClientName,
    required this.calculateDuration,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final duration = calculateDuration(appointment);
    final status = appointment['status'] as String;
    final bool isWide = MediaQuery.of(context).size.width >= 800;

    Color statusColor = primaryColor;
    String statusText = '';

    switch (status) {
      case 'confirmada':
        statusColor = confirmedColor;
        statusText = 'Confirmada';
        break;
      case 'completa':
        statusColor = completeColor;
        statusText = 'Completada';
        break;
      case 'pendiente':
        statusColor = pendingColor;
        statusText = 'Pendiente';
        break;
      case 'cancelada':
        statusColor = cancelledColor;
        statusText = 'Cancelada';
        break;
      case 'aplazada':
        statusColor = postponedColor;
        statusText = 'Aplazada';
        break;
      case 'perdida':
        statusColor = missedColor;
        statusText = 'Perdida';
        break;
    }

    final Color cardBgColor = isDark ? Colors.grey[800]! : Colors.white;
    final Color cardBorderColor = isDark ? Colors.grey[700]! : Colors.grey[200]!;
    final Color shadowColor = isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08);

    // No mostrar el botón de aplazar si la cita ya está aplazada o cancelada
    final bool canPostpone = status != 'aplazada' && status != 'cancelada' && status != 'completa';

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hora y duración
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
                // Información del cliente y servicio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getClientName(appointment),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textColor : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getServiceName(appointment),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? hintColor : Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                      if (appointment['price'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '\$${appointment['price']?.toString() ?? '0.00'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Estado de la cita
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

            // Información adicional y botones de acción
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
                    // Botón de eliminar
                    Container(
                      width: isWide ? 36 : 32,
                      height: isWide ? 36 : 32,
                      decoration: BoxDecoration(
                        color: errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: errorColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.delete, size: isWide ? 20 : 18),
                        color: errorColor,
                        onPressed: isLoading ? null : onDelete,
                        tooltip: 'Eliminar cita',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón de editar
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
                    // Botón de aplazar (solo si se puede aplazar)
                    if (canPostpone) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: isWide ? 36 : 32,
                        height: isWide ? 36 : 32,
                        decoration: BoxDecoration(
                          color: postponedColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: postponedColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.schedule, size: isWide ? 20 : 18),
                          color: postponedColor,
                          onPressed: isLoading ? null : onPostpone,
                          tooltip: 'Aplazar cita',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getServiceName(Map<String, dynamic> appointment) {
    final services = appointment['services'];
    if (services != null && services is Map) {
      return services['name'] as String? ?? 'Sin servicio';
    }
    return 'Sin servicio';
  }
}

//[------------- WIDGET: AppointmentPopup (Popup de Creación/Edición de Cita) --------------]
class AppointmentPopup extends StatefulWidget {
  final VoidCallback onClose;
  final bool isDark;
  final String employeeId;
  final Map<String, dynamic>? initialAppointment;
  final Map<String, dynamic>? initialClientData;
  final bool isPostponedAppointment;
  final VoidCallback onSaved;
  final VoidCallback? onServicesUpdated; 

  const AppointmentPopup({
    super.key,
    required this.onClose,
    required this.isDark,
    required this.employeeId,
    this.initialAppointment,
    this.initialClientData,
    this.isPostponedAppointment = false,
    required this.onSaved,
     this.onServicesUpdated, 
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  String? _selectedServiceId;
  bool _loadingServices = true;
  final _notesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _selectedDuration = 60;
  String _selectedStatus = 'pendiente';
  bool _notifyMe = true;

  Map<String, dynamic>? _selectedClient;
  bool _isClientSelectionPopupOpen = false;
  bool _isSaving = false;
  
  Key _datePickerKey = UniqueKey();

  List<String> _availableStatuses = [];

  @override
  void initState() {
    super.initState();

    // Obtener los estados disponibles del servicio (excluye 'aplazada')
    _availableStatuses = AppointmentsService.getAvailableStatusesForForm();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
    _loadServices();
    _initializeFields();
  }

  void _initializeFields() {
    // Rellenar campos si está en modo edición o con datos iniciales de cliente
    if (widget.initialAppointment != null) {
      final appointment = widget.initialAppointment!;
      
      // Obtener datos del cliente de la relación
      final clientsData = appointment['clients'];
      if (clientsData != null) {
        if (clientsData is List && clientsData.isNotEmpty) {
          final client = clientsData[0];
          _clientNameCtrl.text = client['name']?.toString() ?? '';
          _clientPhoneCtrl.text = client['phone']?.toString() ?? '';
          _clientEmailCtrl.text = client['email']?.toString() ?? '';
          _selectedClient = {
            'id': client['id'],
            'name': client['name'],
            'phone': client['phone'],
            'email': client['email'],
          };
        } else if (clientsData is Map) {
          _clientNameCtrl.text = clientsData['name']?.toString() ?? '';
          _clientPhoneCtrl.text = clientsData['phone']?.toString() ?? '';
          _clientEmailCtrl.text = clientsData['email']?.toString() ?? '';
          _selectedClient = {
            'id': clientsData['id'],
            'name': clientsData['name'],
            'phone': clientsData['phone'],
            'email': clientsData['email'],
          };
        }
      }

      // Cargar servicio desde la relación con services
      final serviceData = appointment['services'];
      if (serviceData != null && serviceData is Map) {
        _selectedServiceId = serviceData['id'];
        _descriptionCtrl.text = serviceData['name'] ?? '';
      } else {
        // Cita sin servicio (durante migración)
        _selectedServiceId = null;
        _descriptionCtrl.text = '';
      }
      _notesCtrl.text = appointment['notes']?.toString() ?? '';
      _priceCtrl.text = appointment['price']?.toString() ?? '';
      _depositCtrl.text = appointment['deposit_paid']?.toString() ?? '0.00';

      _selectedDate = DateTime.parse(appointment['start_time']);
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
      
      final startTime = DateTime.parse(appointment['start_time']);
      final endTime = DateTime.parse(appointment['end_time']);
      _selectedDuration = endTime.difference(startTime).inMinutes;
      
      // Asegurar que el estado de la cita esté en los estados disponibles
      String currentStatus = appointment['status'] ?? 'pendiente';
      if (_availableStatuses.contains(currentStatus)) {
        _selectedStatus = currentStatus;
      } else {
        // Si es una cita aplazada siendo editada, usar pendiente como estado por defecto
        _selectedStatus = 'pendiente';
      }
    } else if (widget.initialClientData != null) {
      _clientNameCtrl.text = widget.initialClientData!['name']?.toString() ?? '';
      _clientPhoneCtrl.text = widget.initialClientData!['phone']?.toString() ?? '';
      _clientEmailCtrl.text = widget.initialClientData!['email']?.toString() ?? '';
      _selectedClient = widget.initialClientData;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientEmailCtrl.dispose();
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    _priceCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final services = await ServicesService.getServices(userId, onlyActive: true);
      
      if (mounted) {
        setState(() {
          _services = services;
          
          // Si estamos editando y el servicio está inactivo, agregarlo a la lista
          if (widget.initialAppointment != null) {
            final serviceData = widget.initialAppointment!['services'];
            if (serviceData != null && serviceData is Map) {
              final serviceId = serviceData['id'];
              final isActive = serviceData['is_active'] as bool? ?? true;
              
              // Si el servicio está inactivo, agregarlo a la lista
              if (!isActive) {
                final serviceExists = _services.any((s) => s['id'] == serviceId);
                if (!serviceExists) {
                  _services.add(Map<String, dynamic>.from(serviceData));
                }
              }
            }
          }
          
          _loadingServices = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
      if (mounted) {
        setState(() => _loadingServices = false);
      }
    }
  }

  void _closeWithAnimation() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _selectClient() {
    // Solo permitir selección si no es una cita aplazada
    if (!widget.isPostponedAppointment) {
      setState(() {
        _isClientSelectionPopupOpen = true;
      });
    }
  }

  void _onClientSelected(Map<String, dynamic>? client) {
    setState(() {
      _selectedClient = client;
      if (client != null) {
        _clientNameCtrl.text = client['name']?.toString() ?? '';
        _clientPhoneCtrl.text = client['phone']?.toString() ?? '';
        _clientEmailCtrl.text = client['email']?.toString() ?? '';
      }
      _isClientSelectionPopupOpen = false;
    });
  }

  void _clearSelectedClient() {
    // Solo permitir limpiar si no es una cita aplazada
    if (!widget.isPostponedAppointment) {
      setState(() {
        _selectedClient = null;
        _clientNameCtrl.clear();
        _clientPhoneCtrl.clear();
        _clientEmailCtrl.clear();
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Validar servicio seleccionado
    if (_selectedClient == null) {
      _showSafeMessage('Debes seleccionar un cliente', isError: true);
      setState(() => _isSaving = false);
      return;
    }

    // Verificar que el servicio seleccionado aún existe y está activo
      final selectedService = _services.firstWhere(
        (s) => s['id'] == _selectedServiceId,
        orElse: () => <String, dynamic>{},
      );
      
      if (selectedService.isEmpty) {
        _showToast('El servicio seleccionado ya no existe. Por favor selecciona otro.', isError: true);
        setState(() => _isSaving = false);
        return;
      }
      
      if (selectedService['is_active'] == false) {
        _showToast('El servicio seleccionado está inactivo. Por favor selecciona otro.', isError: true);
        setState(() => _isSaving = false);
        return;
      }

    if (_selectedClient == null) {
      _showSafeMessage('Debes seleccionar un cliente', isError: true);
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final endDateTime = selectedDateTime.add(Duration(minutes: _selectedDuration));

      // Verificar disponibilidad de horario
      final isAvailable = await AppointmentsService.isTimeSlotAvailable(
        employeeId: widget.employeeId,
        startTime: selectedDateTime,
        endTime: endDateTime,
        excludeAppointmentId: widget.initialAppointment?['id'],
      );

      // Verificar mounted after each asynchronous operation
      if (!mounted) return;

      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
        _showSafeMessage('El horario seleccionado no está disponible', isError: true);
        return;
      }

      double? price;
      double? depositPaid;

      if (_priceCtrl.text.isNotEmpty) {
        price = double.tryParse(_priceCtrl.text);
      }

      if (_depositCtrl.text.isNotEmpty) {
        depositPaid = double.tryParse(_depositCtrl.text);
      }

      if (widget.initialAppointment != null) {
        // Actualizar cita existente
        await AppointmentsService.updateAppointment(
          appointmentId: widget.initialAppointment!['id'],
          employeeId: widget.employeeId,
          clientId: _selectedClient!['id'],
          startTime: selectedDateTime,
          endTime: endDateTime,
          serviceId: _selectedServiceId!,
          status: _selectedStatus,
          price: price,
          depositPaid: depositPaid ?? 0.00,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
      } else {
        // Crear nueva cita
        await AppointmentsService.createAppointment(
          clientId: _selectedClient!['id'],
          employeeId: widget.employeeId,
          startTime: selectedDateTime,
          endTime: endDateTime,
          serviceId: _selectedServiceId!,
          status: _selectedStatus,
          price: price,
          depositPaid: depositPaid ?? 0.00,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
      }

      if (_notifyMe && (_selectedStatus == 'confirmada' || _selectedStatus == 'pendiente')) {
        try {
          // Schedule notification using the scheduler
          await NotificationScheduler.scheduleAppointmentNotification(
            appointmentId: widget.initialAppointment?['id'] ?? 'new_appointment',
            clientName: _selectedClient!['name'] ?? 'Cliente',
            appointmentTime: selectedDateTime,
            employeeId: widget.employeeId,
          );
        } catch (e) {
          // Don't fail the appointment creation if notification fails
          if (kDebugMode) {
            print('Error programando notificación automática: $e');
          }
        }
      }

      // Verify mounted before any operation with context or setState
      if (!mounted) return;

      // Reset saving state before closing
      setState(() {
        _isSaving = false;
      });

      // Call callback that is responsible for closing the popup and updating
      widget.onSaved();
      
    } catch (e) {
      // Verify mounted before showing error
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      
      _showSafeMessage('Error al guardar la cita: ${e.toString()}', isError: true);
    }
  }

  void _showSafeMessage(String message, {bool isError = false}) {
    debugPrint('Message: $message');
    
    // Only try to show SnackBar if we have a valid scaffold state and are mounted
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState != null && mounted) {
      try {
        final scaffoldMessenger = ScaffoldMessenger.of(scaffoldState.context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? errorColor : successColor,
            duration: Duration(seconds: isError ? 4 : 3),
          ),
        );
      } catch (e) {
        debugPrint('Could not show SnackBar: $e');
      }
    }
  }
  void _showToast(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? errorColor : successColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<void> _showServicesManagementDialog() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ServicesManagementDialog(
        userId: userId,
        isDark: widget.isDark,
      ),
    );
    await _loadServices();
    if (result == true && widget.onServicesUpdated != null) {
      widget.onServicesUpdated!();
    }
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
                  child: Stack(
                    children: [
                      Container(
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
                      if (_isClientSelectionPopupOpen && !widget.isPostponedAppointment)
                        Positioned.fill(
                          child: ClientSelectionDialog(
                            isDark: widget.isDark,
                            employeeId: widget.employeeId,
                            onClientSelected: _onClientSelected,
                          ),
                        ),
                    ],
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
    final String title = widget.initialAppointment != null ? 'Editar Cita' : 
                        widget.isPostponedAppointment ? 'Nueva Cita - Cliente Fijo' : 'Nueva Cita';
    final String subtitle = widget.initialAppointment != null ? 'Modifica los detalles de la cita' : 
                           widget.isPostponedAppointment ? 'Programa una nueva fecha para el cliente seleccionado' : 
                           'Programa una nueva cita con el cliente';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isPostponedAppointment ? [
                postponedColor,
                postponedColor.withValues(alpha: 0.8),
              ] : [
                primaryColor,
                primaryColor.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            widget.isPostponedAppointment ? Icons.schedule : Icons.event_available,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? textColor : Colors.black87,
                ),
              ),
              Text(
                subtitle,
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
            onPressed: _isSaving ? null : _closeWithAnimation,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: widget.isPostponedAppointment ? postponedColor : primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Inf. Cliente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? textColor : Colors.black87,
                    ),
                  ),
                  if (widget.isPostponedAppointment) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: postponedColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: postponedColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'BLOQUEADO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: postponedColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (_selectedClient != null && !widget.isPostponedAppointment)
                  IconButton(
                    icon: Icon(Icons.clear, color: widget.isDark ? hintColor : Colors.grey[600]),
                    onPressed: _clearSelectedClient,
                    tooltip: 'Deseleccionar cliente',
                  ),
                ElevatedButton.icon(
                  onPressed: _isSaving || widget.isPostponedAppointment ? null : _selectClient,
                  icon: Icon(Icons.search, color: Colors.black, size: 18),
                  label: Text(
                    widget.isPostponedAppointment ? 'Cliente Fijo' :
                    _selectedClient != null ? 'Cambiar Cliente' : 'Buscar Cliente',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isPostponedAppointment ? postponedColor : primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _clientNameCtrl,
          style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
          decoration: _buildInputDecoration('Nombre completo *', Icons.person_outline),
          readOnly: true, // Siempre solo lectura porque viene de la selección
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
                readOnly: true,
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
                readOnly: true,
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
              color: widget.isPostponedAppointment ? postponedColor : primaryColor,
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
        Row(
          children: [
            Expanded(
              child: _loadingServices
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(
                          color: primaryColor.withValues(alpha:0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Cargando servicios...'),
                        ],
                      ),
                    )
                  : _services.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(
                              color: errorColor.withValues(alpha:0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: errorColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No hay servicios. Crea uno usando el botón →',
                                  style: TextStyle(
                                    color: widget.isDark ? textColor : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedServiceId, 
                          dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
                          decoration: _buildInputDecoration('Servicio *', Icons.work_outline),
                          style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Debes seleccionar un servicio';
                            }
                            return null;
                          },
                          items: _services.map((service) {
                              final isActive = service['is_active'] as bool? ?? true;
                              return DropdownMenuItem<String>(
                                value: service['id'],
                                child: Text(
                                  service['name'] + (!isActive ? ' (Inactivo)' : ''),
                                  style: TextStyle(
                                    color: widget.isDark ? textColor : Colors.black87,
                                    decoration: !isActive ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedServiceId = value;
                              if (value != null) {
                                final service = _services.firstWhere((s) => s['id'] == value);
                                _descriptionCtrl.text = service['name'];
                              }
                            });
                          },
                          hint: Text(
                            'Seleccionar servicio',
                            style: TextStyle(
                              color: widget.isDark ? hintColor : Colors.grey[600],
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha:0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.black),
                tooltip: 'Gestionar servicios',
                onPressed: () async {
                  await _showServicesManagementDialog();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: _datePickerKey,
                onTap: () async {
                  setState(() {
                    _datePickerKey = UniqueKey();
                  });
                  
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: widget.isPostponedAppointment ? postponedColor : primaryColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null && mounted) {
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
                        color: widget.isPostponedAppointment ? postponedColor : primaryColor,
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
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: widget.isPostponedAppointment ? postponedColor : primaryColor,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null && mounted) {
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
                        color: widget.isPostponedAppointment ? postponedColor : primaryColor,
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
            Flexible(
              flex: 1,
              child: DropdownButtonFormField<int>(
                initialValue: _selectedDuration,
                decoration: _buildInputDecoration('Duración', Icons.timer_outlined, isDropdown: true),
                dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                items: [30, 60, 90, 120, 180, 240].map((duration) {
                  return DropdownMenuItem(
                    value: duration,
                    child: Text('$duration min'),
                  );
                }).toList(),
                onChanged: _isSaving ? null : (value) => setState(() => _selectedDuration = value!),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              flex: 1,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: _buildInputDecoration('Estado', Icons.flag_outlined, isDropdown: true),
                dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                items: _availableStatuses.map((status) {
                  String displayText = '';
                  switch (status) {
                    case 'pendiente':
                      displayText = 'Pendiente';
                      break;
                    case 'confirmada':
                      displayText = 'Confirmada';
                      break;
                    case 'completa':
                      displayText = 'Completada';
                      break;
                    case 'cancelada':
                      displayText = 'Cancelada';
                      break;
                    case 'perdida':
                      displayText = 'Perdida';
                      break;
                  }
                  return DropdownMenuItem(
                    value: status,
                    child: Text(displayText),
                  );
                }).toList(),
                onChanged: _isSaving ? null : (value) => setState(() => _selectedStatus = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.3) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: _notifyMe 
                    ? (widget.isPostponedAppointment ? postponedColor : primaryColor)
                    : (widget.isDark ? Colors.grey[500] : Colors.grey[400]),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notificarme de esta cita',
                  style: TextStyle(
                    color: widget.isDark ? textColor : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: _notifyMe,
                onChanged: _isSaving ? null : (value) => setState(() => _notifyMe = value),
                activeThumbColor: widget.isPostponedAppointment ? postponedColor : primaryColor,
                inactiveThumbColor: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                inactiveTrackColor: widget.isDark ? Colors.grey[700] : Colors.grey[300],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _priceCtrl,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                decoration: _buildInputDecoration('Precio *', Icons.attach_money_outlined),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El precio es requerido';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'El precio debe ser mayor a 0';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _depositCtrl,
                style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                decoration: _buildInputDecoration('Depósito pagado', Icons.payment_outlined),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final deposit = double.tryParse(value);
                    if (deposit == null || deposit < 0) {
                      return 'Ingresa un depósito válido';
                    }
                    if (_priceCtrl.text.isNotEmpty) {
                      final price = double.tryParse(_priceCtrl.text);
                      if (price != null && deposit > price) {
                        return 'El depósito no puede ser mayor al precio';
                      }
                    }
                  }
                  return null;
                },
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
    final Color accentColor = widget.isPostponedAppointment ? postponedColor : primaryColor;
    
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: widget.isDark ? hintColor : Colors.grey[600],
        fontSize: 14,
      ),
      prefixIcon: isDropdown ? null : Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: accentColor,
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
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      filled: true,
      fillColor: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildActionButtons() {
    final String buttonText = widget.initialAppointment != null ? 'Actualizar Cita' : 'Guardar Cita';
    final Color buttonColor = widget.isPostponedAppointment ? postponedColor : primaryColor;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: _isSaving ? null : _closeWithAnimation,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  buttonColor,
                  buttonColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAppointment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.save,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          buttonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

//[------------- WIDGET: AppointmentDetailsDialog (Diálogo de Detalles de Cita) --------------]
class AppointmentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isDark;
  final VoidCallback? onEdit;

  const AppointmentDetailsDialog({
    super.key,
    required this.appointment,
    required this.isDark,
    this.onEdit,
  });

  String _getClientName(Map<String, dynamic> appointment) {
    final clientsData = appointment['clients'];
    if (clientsData is List && clientsData.isNotEmpty) {
      return clientsData[0]['name']?.toString() ?? 'Cliente Desconocido';
    } else if (clientsData is Map) {
      return clientsData['name']?.toString() ?? 'Cliente Desconocido';
    }
    return 'Cliente Desconocido';
  }
  String _getServiceName(Map<String, dynamic> appointment) {
    final services = appointment['services'];
    if (services != null && services is Map) {
      return services['name'] as String? ?? 'Sin servicio';
    }
    return 'Sin servicio';
  }

  String _getClientPhone(Map<String, dynamic> appointment) {
    final clientsData = appointment['clients'];
    if (clientsData is List && clientsData.isNotEmpty) {
      return clientsData[0]['phone']?.toString() ?? '';
    } else if (clientsData is Map) {
      return clientsData['phone']?.toString() ?? '';
    }
    return '';
  }

  String _getClientEmail(Map<String, dynamic> appointment) {
    final clientsData = appointment['clients'];
    if (clientsData is List && clientsData.isNotEmpty) {
      return clientsData[0]['email']?.toString() ?? '';
    } else if (clientsData is Map) {
      return clientsData['email']?.toString() ?? '';
    }
    return '';
  }

  int _calculateDuration(Map<String, dynamic> appointment) {
    try {
      final startTime = DateTime.parse(appointment['start_time']);
      final endTime = DateTime.parse(appointment['end_time']);
      return endTime.difference(startTime).inMinutes;
    } catch (e) {
      return 60; // Valor por defecto
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(appointment['start_time']);
    final duration = _calculateDuration(appointment);
    final status = appointment['status'] as String;

    Color statusColor = primaryColor;
    String statusText = '';

    switch (status) {
      case 'confirmada':
        statusColor = confirmedColor;
        statusText = 'Confirmada';
        break;
      case 'completa':
        statusColor = completeColor;
        statusText = 'Completada';
        break;
      case 'pendiente':
        statusColor = pendingColor;
        statusText = 'Pendiente';
        break;
      case 'cancelada':
        statusColor = cancelledColor;
        statusText = 'Cancelada';
        break;
      case 'aplazada':
        statusColor = postponedColor;
        statusText = 'Aplazada';
        break;
      case 'perdida':
      statusColor = missedColor;
      statusText = 'Perdida';
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
              // Encabezado del diálogo
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

              // Información detallada de la cita
              _buildDetailRow(
                Icons.person,
                'Cliente',
                _getClientName(appointment),
                isDark,
              ),
             _buildDetailRow(
                Icons.work,
                'Servicio',
                _getServiceName(appointment),
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
              if (appointment['price'] != null)
                _buildDetailRow(
                  Icons.attach_money,
                  'Precio',
                  '\$${appointment['price']?.toString() ?? '0.00'}',
                  isDark,
                ),
              if (appointment['deposit_paid'] != null && appointment['deposit_paid'] > 0)
                _buildDetailRow(
                  Icons.payment,
                  'Depósito pagado',
                  '\$${appointment['deposit_paid']?.toString() ?? '0.00'}',
                  isDark,
                ),
              if (_getClientPhone(appointment).isNotEmpty)
                _buildDetailRow(
                  Icons.phone,
                  'Teléfono',
                  _getClientPhone(appointment),
                  isDark,
                ),
              if (_getClientEmail(appointment).isNotEmpty)
                _buildDetailRow(
                  Icons.email,
                  'Email',
                  _getClientEmail(appointment),
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
                  if (onEdit != null) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: onEdit,
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

//[------------- WIDGET: AnimatedAppearance (Animación de Aparición) --------------]
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

//[------------- WIDGET: BlurredBackground (Fondo Difuminado) --------------]
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

//[------------- WIDGET: ClientSelectionDialog (Diálogo de Selección de Cliente) --------------]
class ClientSelectionDialog extends StatefulWidget {
  final bool isDark;
  final String employeeId;
  final Function(Map<String, dynamic>?) onClientSelected;

  const ClientSelectionDialog({
    super.key,
    required this.isDark,
    required this.employeeId,
    required this.onClientSelected,
  });

  @override
  State<ClientSelectionDialog> createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<ClientSelectionDialog> {
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  bool _loadingClients = false;
  String? _errorClients;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterClients);
    _fetchClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _loadingClients = true;
      _errorClients = null;
    });
    try {
      final clients = await ClientsService.getClients(widget.employeeId);
      // Filtrar clientes activos
      final activeClients = clients.where((client) => client['status'] == true).toList();
      if (mounted) {
        setState(() {
          _allClients = activeClients;
          _filterClients();
          _loadingClients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorClients = 'Error al cargar clientes: $e';
          _loadingClients = false;
        });
      }
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        final name = client['name']?.toString().toLowerCase() ?? '';
        final email = client['email']?.toString().toLowerCase() ?? '';
        final phone = client['phone']?.toString().toLowerCase() ?? '';
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seleccionar Cliente',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? textColor : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: widget.isDark ? textColor : Colors.black87),
                      onPressed: () => widget.onClientSelected(null),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, email o teléfono...',
                    hintStyle: TextStyle(color: widget.isDark ? hintColor : Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: widget.isDark ? hintColor : Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: widget.isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              Expanded(
                child: _loadingClients
                    ? const Center(child: CircularProgressIndicator(color: primaryColor))
                    : _errorClients != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _errorClients!,
                                style: TextStyle(color: errorColor, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _filteredClients.isEmpty
                            ? Center(
                                child: Text(
                                  'No se encontraron clientes.',
                                  style: TextStyle(color: widget.isDark ? hintColor : Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                itemCount: _filteredClients.length,
                                itemBuilder: (context, index) {
                                  final client = _filteredClients[index];
                                  return Card(
                                    color: widget.isDark ? Colors.grey[800] : Colors.white,
                                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: primaryColor.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: CircleAvatar(
                                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                                        child: Text(
                                          client['name'] != null && client['name'].isNotEmpty
                                              ? client['name'][0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(
                                        client['name'] ?? 'Nombre Desconocido',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: widget.isDark ? textColor : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (client['email'] != null && client['email'].isNotEmpty)
                                            Text(
                                              client['email'],
                                              style: TextStyle(color: widget.isDark ? hintColor : Colors.grey[600]),
                                            ),
                                          if (client['phone'] != null && client['phone'].isNotEmpty)
                                            Text(
                                              client['phone'],
                                              style: TextStyle(color: widget.isDark ? hintColor : Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                      onTap: () {
                                        widget.onClientSelected(client);
                                      },
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Clase placeholder para NotificationsBottomSheet
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Notificaciones'),
    );
  }
}
//[------------- DIÁLOGO DE GESTIÓN DE SERVICIOS --------------]
class ServicesManagementDialog extends StatefulWidget {
  final String userId;
  final bool isDark;

  const ServicesManagementDialog({
    super.key,
    required this.userId,
    required this.isDark,
  });

  @override
  State<ServicesManagementDialog> createState() => _ServicesManagementDialogState();
}

class _ServicesManagementDialogState extends State<ServicesManagementDialog> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      setState(() => _loading = true);
      
      final services = await ServicesService.getServices(
        widget.userId,
        onlyActive: _showInactive ? null : true,
      );
      
      if (mounted) {
        setState(() {
          _services = services;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando servicios: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }


  void _showToast(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? errorColor : successColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<void> _createService() async {
    final nameController = TextEditingController();
    if (!mounted) return;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Nuevo Servicio',
              style: TextStyle(
                color: widget.isDark ? textColor : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Nombre del servicio *',
                labelStyle: TextStyle(
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.work_outline,
                  color: widget.isDark ? primaryColor : Colors.black54,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              
              if (name.isEmpty) {
                Navigator.pop(dialogContext, {'error': 'El nombre del servicio es requerido'});
                return;
              }
              
              final exists = await ServicesService.serviceNameExists(
                widget.userId,
                name,
              );
              
              if (exists) {
                Navigator.pop(dialogContext, {'error': 'Ya existe un servicio con ese nombre'});
                return;
              }
              
              try {
                await ServicesService.createService(
                  employeeId: widget.userId,
                  name: name,
                );

                Navigator.pop(dialogContext, {'success': true, 'updated': true});  // ← CAMBIO
              } catch (e) {
                Navigator.pop(dialogContext, {'error': 'Error al crear servicio: $e'});
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    
    if (!mounted) return;
    
    if (result != null) {
      if (result['success'] == true) {
        _showToast('✓ Servicio creado exitosamente');
        await _loadServices();
        
        // Indicar que hubo cambios
        if (result['updated'] == true && mounted) {
          Navigator.pop(context, true);  // ← AGREGAR ESTO
        }
      } else if (result['error'] != null) {
        _showToast(result['error'], isError: true);
      }
    }
  }

  Future<void> _editService(Map<String, dynamic> service) async {
    final nameController = TextEditingController(text: service['name']);
    final serviceId = service['id'];
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Editar Servicio',
                style: TextStyle(
                  color: widget.isDark ? textColor : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Nombre del servicio *',
                labelStyle: TextStyle(
                  color: widget.isDark ? hintColor : Colors.grey[600],
                ),
                prefixIcon: Icon(
                  Icons.work_outline,
                  color: widget.isDark ? primaryColor : Colors.black54,
                ),
                filled: true,
                fillColor: widget.isDark ? Colors.grey[800] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              
              if (newName.isEmpty) {
                Navigator.pop(dialogContext, {'error': 'El nombre del servicio es requerido'});
                return;
              }
              
              final exists = await ServicesService.serviceNameExists(
                widget.userId,
                newName,
                excludeId: serviceId,
              );
              
              if (exists) {
                Navigator.pop(dialogContext, {'error': 'Ya existe un servicio con ese nombre'});
                return;
              }
              
              try {
                await ServicesService.updateService(
                  serviceId: serviceId,
                  employeeId: widget.userId,
                  name: newName,
                );
                
                Navigator.pop(dialogContext, {'success': true, 'updated': true});  // ← CAMBIO
              } catch (e) {
                Navigator.pop(dialogContext, {'error': 'Error al actualizar servicio: $e'});
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      if (result['success'] == true) {
        _showToast('✓ Servicio actualizado exitosamente');
        await _loadServices();
        
        // Indicar que hubo cambios
        if (result['updated'] == true) {
          // Cerrar el diálogo con confirmación de cambios
          if (mounted) {
            Navigator.pop(context, true);  // ← AGREGAR ESTO
          }
        }
      } else if (result['error'] != null) {
        _showToast(result['error'], isError: true);
      }
    }
  }

  Future<void> _toggleServiceStatus(Map<String, dynamic> service) async {
    final serviceId = service['id'];
    final isActive = service['is_active'] as bool;
    final newStatus = !isActive;
    
    try {
      await ServicesService.toggleServiceStatus(
        serviceId: serviceId,
        employeeId: widget.userId,
        newStatus: newStatus,
      );
      
      _showToast(
        newStatus 
            ? '✓ Servicio activado exitosamente' 
            : '✓ Servicio desactivado exitosamente'
      );
      
      await _loadServices();
    } catch (e) {
      _showToast('Error al cambiar estado: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gestión de Servicios',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            
            // Filtro mostrar inactivos
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: widget.isDark ? textColor : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mostrar inactivos',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDark ? textColor : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _showInactive,
                    onChanged: (value) {
                      setState(() => _showInactive = value);
                      _loadServices();
                    },
                    activeTrackColor: primaryColor.withValues(alpha:0.5),
                    activeThumbColor: primaryColor,
                  ),
                ],
              ),
            ),
            
            // Lista de servicios
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _services.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: widget.isDark ? Colors.grey[700] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay servicios',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Crea tu primer servicio',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _services.length,
                          itemBuilder: (context, index) {
                            final service = _services[index];
                            final isActive = service['is_active'] as bool;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: widget.isDark ? Colors.grey[800] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? primaryColor.withValues(alpha:0.3)
                                      : Colors.grey.withValues(alpha:0.2),
                                  width: 1,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isActive ? primaryColor : Colors.grey)
                                        .withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.work_outline,
                                    color: isActive ? primaryColor : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  service['name'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark
                                        ? (isActive ? textColor : Colors.grey[500])
                                        : (isActive ? Colors.black87 : Colors.grey[600]),
                                    decoration: isActive ? null : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Text(
                                  isActive ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive ? successColor : Colors.grey,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: widget.isDark ? primaryColor : Colors.black54,
                                        size: 20,
                                      ),
                                      onPressed: () => _editService(service),
                                      tooltip: 'Editar',
                                    ),
                                    Switch(
                                      value: isActive,
                                      onChanged: (value) => _toggleServiceStatus(service),
                                      activeTrackColor: primaryColor.withValues(alpha:0.5),
                                      activeThumbColor: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // Botón crear servicio
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                border: Border(
                  top: BorderSide(
                    color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text(
                    'Crear Nuevo Servicio',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _createService,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}