import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'appbar.dart';
import 'theme_provider.dart';
import '../integrations/appointments_service.dart';

//[-------------CONSTANTES DE ESTILO Y TEMA--------------]
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class ClientProfilePage extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientProfilePage({super.key, required this.client});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _clientStats;
  List<Map<String, dynamic>>? _allAppointments;
  String? _userName;
  late Future<void> _loadUserData;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Filtros
  String _selectedFilter = 'Recientes';
  final List<String> _filterOptions = ['Recientes', 'Todos', 'Completadas', 'Confirmadas', 'Pendientes', 'Canceladas', 'Perdidas', 'Aplazadas'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _loadClientData();
    _loadUserData = _fetchUserData();
    _animationController.forward();
  }

  //[-------------CARGA DE DATOS REALES DEL CLIENTE--------------]
  Future<void> _loadClientData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = Supabase.instance.client.auth.currentUser!;
      final clientId = widget.client['id'] as String;

      final appointments = await AppointmentsService.getFilteredAppointments(
        employeeId: user.id,
        status: null,
      );

      final clientAppointments = appointments.where((apt) => apt['client_id'] == clientId).toList();
      clientAppointments.sort((a, b) => DateTime.parse(b['start_time']).compareTo(DateTime.parse(a['start_time'])));

      final completed = clientAppointments.where((apt) => apt['status'] == 'completa').toList();
      final lost = clientAppointments.where((apt) => apt['status'] == 'perdida').toList();
      final pending = clientAppointments.where((apt) => apt['status'] == 'pendiente').toList();
      final confirmed = clientAppointments.where((apt) => apt['status'] == 'confirmada').toList();
      final cancelled = clientAppointments.where((apt) => apt['status'] == 'cancelada').toList();
      final postponed = clientAppointments.where((apt) => apt['status'] == 'aplazada').toList();
      
      double totalSpent = 0.0;
      
      for (final appointment in completed) {
        final price = appointment['price'];
        if (price != null) {
          totalSpent += (price as num).toDouble();
        }
      }
      
      for (final appointment in lost) {
        final deposit = appointment['deposit_paid'];
        if (deposit != null && (deposit as num) > 0) {
          totalSpent += (deposit).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _clientStats = {
            'total_sessions': clientAppointments.length,
            'appointments_count': completed.length,
            'total_spent': totalSpent,
            'pending_appointments': pending.length + confirmed.length,
            'pending': pending.length,
            'confirmed': confirmed.length,
            'cancelled': cancelled.length,
            'lost': lost.length,
            'postponed': postponed.length,
          };
          _allAppointments = clientAppointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos del cliente: $e';
          _isLoading = false;
        });
      }
    }
  }

  //[-------------OPERACIONES CON SUPABASE--------------]
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
      // Logging
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Logging
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getClientInitials() {
    final name = widget.client['name'] as String? ?? 'Cliente';
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'C';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return 'Completada';
      case 'confirmada': return 'Confirmada';
      case 'pendiente': return 'Pendiente';
      case 'cancelada': return 'Cancelada';
      case 'perdida': return 'Perdida';
      case 'aplazada': return 'Aplazada';
      default: return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return const Color(0xFF4CAF50);
      case 'confirmada': return const Color(0xFF2196F3);
      case 'pendiente': return const Color(0xFFFF9800);
      case 'cancelada': return const Color(0xFF9E9E9E);
      case 'perdida': return const Color(0xFFFF5722);
      case 'aplazada': return const Color(0xFF9C27B0);
      default: return primaryColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return Icons.check_circle;
      case 'pendiente': return Icons.schedule;
      case 'confirmada': return Icons.event_available;
      case 'cancelada': return Icons.cancel;
      case 'perdida': return Icons.money_off;
      case 'aplazada': return Icons.update;
      default: return Icons.event;
    }
  }

  List<Map<String, dynamic>> _getFilteredAppointments() {
    if (_allAppointments == null) return [];
    
    if (_selectedFilter == 'Recientes') {
      return _allAppointments!.take(3).toList();
    } else if (_selectedFilter == 'Todos') {
      return _allAppointments!;
    }
    
    return _allAppointments!.where((item) {
      switch (_selectedFilter) {
        case 'Completadas': return item['status'] == 'completa';
        case 'Canceladas': return item['status'] == 'cancelada';
        case 'Pendientes': return item['status'] == 'pendiente';
        case 'Confirmadas': return item['status'] == 'confirmada';
        case 'Perdidas': return item['status'] == 'perdida';
        case 'Aplazadas': return item['status'] == 'aplazada';
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDark;
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;

    return FutureBuilder(
      future: _loadUserData,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: isDark ? backgroundColor : Colors.grey[100],
          appBar: CustomAppBar(
            title: 'Perfil del Cliente',
            onNotificationPressed: () {},
            isWide: isWide,
            showBackButton: true,
          ),
          drawer: isWide
              ? null
              : Drawer(
                  child: _userName != null
                      ? NavPanel(user: user, onLogout: _logout, userName: _userName!)
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
                              ? NavPanel(user: user, onLogout: _logout, userName: _userName!)
                              : const Center(child: CircularProgressIndicator()),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildMainContent(isDark, isWide),
                            ),
                          ),
                        ),
                      ],
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildMainContent(isDark, isWide),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(bool isDark, bool isWide) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text('Cargando datos del cliente...', style: TextStyle(color: primaryColor)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: errorColor),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: errorColor, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadClientData,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Reintentar', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClientInfoCard(isDark),
                const SizedBox(height: 16),
                _buildStatsCards(isDark, isWide),
                const SizedBox(height: 24),
                _buildActionButtons(isDark),
                const SizedBox(height: 24),
                _buildFilterSection(isDark),
                const SizedBox(height: 16),
                _buildAppointmentsList(isDark),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientInfoCard(bool isDark) {
    final clientName = widget.client['name'] as String? ?? 'Cliente';
    final clientPhone = widget.client['phone'] as String? ?? 'No registrado';
    final clientEmail = widget.client['email'] as String? ?? 'No registrado';
    final registrationDate = widget.client['registration_date'] as String? ?? DateTime.now().toIso8601String();
    
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getClientInitials(),
                    style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cliente desde ${_formatDate(registrationDate)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.grey[700] : Colors.grey[300], height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.phone, clientPhone, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoItem(Icons.email, clientEmail, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? hintColor : Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isDark, bool isWide) {
    if (_clientStats == null) return const SizedBox.shrink();
    
    return isWide
        ? Row(
            children: [
              Expanded(child: _buildStatCard('${_clientStats!['total_sessions']}', 'Total Citas', Icons.event_note, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('${_clientStats!['appointments_count']}', 'Completadas', Icons.check_circle, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('${_clientStats!['pending_appointments']}', 'Pendientes', Icons.schedule, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('\$${_clientStats!['total_spent'].toStringAsFixed(0)}', 'Total Gastado', Icons.attach_money, isDark)),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_clientStats!['total_sessions']}', 'Total Citas', Icons.event_note, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('${_clientStats!['appointments_count']}', 'Completadas', Icons.check_circle, isDark)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_clientStats!['pending_appointments']}', 'Pendientes', Icons.schedule, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('\$${_clientStats!['total_spent'].toStringAsFixed(0)}', 'Total Gastado', Icons.attach_money, isDark)),
                ],
              ),
            ],
          );
  }

  Widget _buildStatCard(String value, String label, IconData icon, bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? hintColor : Colors.grey[700], fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          // Asegurarse de que los datos del cliente estén en el formato correcto
          final clientData = {
            'id': widget.client['id'],
            'name': widget.client['name'],
            'phone': widget.client['phone'] ?? '',
            'email': widget.client['email'] ?? '',
          };
          
         Navigator.popAndPushNamed(
            context,
            '/appointments',
            arguments: {
              'openNewAppointmentPopup': true,
              'initialClientData': clientData,
            },
          );
        },
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Agendar Nueva Cita',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historial de Citas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? textColor : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              
              // Obtener color según el filtro
              Color chipColor = primaryColor;
              switch (filter) {
                case 'Completadas':
                  chipColor = const Color(0xFF4CAF50); // Verde
                  break;
                case 'Confirmadas':
                  chipColor = const Color(0xFF2196F3); // Azul
                  break;
                case 'Pendientes':
                  chipColor = const Color(0xFFFF9800); // Naranja
                  break;
                case 'Canceladas':
                  chipColor = const Color(0xFF9E9E9E); // Gris
                  break;
                case 'Perdidas':
                  chipColor = const Color(0xFFFF5722); // Rojo
                  break;
                case 'Aplazadas':
                  chipColor = const Color(0xFF9C27B0); // Morado
                  break;
                case 'Recientes':
                case 'Todos':
                  chipColor = primaryColor;
                  break;
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? chipColor.withValues(alpha: 0.25)
                          : chipColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? chipColor
                            : chipColor.withValues(alpha: 0.4),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? chipColor
                            : chipColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList(bool isDark) {
    final filteredAppointments = _getFilteredAppointments();
    
    if (filteredAppointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 0.5),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No hay citas para mostrar',
                style: TextStyle(
                  color: isDark ? hintColor : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${filteredAppointments.length} ${filteredAppointments.length == 1 ? 'registro' : 'registros'}',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? hintColor : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredAppointments.length,
          itemBuilder: (context, index) {
            final appointment = filteredAppointments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAppointmentCard(appointment, isDark),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment, bool isDark) {
    final status = appointment['status'] as String;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final startTime = DateTime.parse(appointment['start_time']);
    final endTime = DateTime.parse(appointment['end_time']);
    final duration = endTime.difference(startTime);
    final durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
    final description = appointment['description'] ?? 'Cita';
    
    double displayAmount = 0.0;
    String amountLabel = 'Precio';
    if (status == 'completa') {
      displayAmount = (appointment['price'] as num?)?.toDouble() ?? 0.0;
    } else if (status == 'perdida') {
      displayAmount = (appointment['deposit_paid'] as num?)?.toDouble() ?? 0.0;
      amountLabel = 'Depósito';
    } else {
      displayAmount = (appointment['price'] as num?)?.toDouble() ?? 0.0;
    }
    
    return AnimatedContainer(
      duration: themeAnimationDuration,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? textColor : Colors.black87,
                        ),
                      ),
                      Text(
                        'Cita',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? hintColor : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.calendar_today, 'Fecha', _formatDate(appointment['start_time']), isDark),
                      const SizedBox(height: 10),
                      _buildDetailItem(Icons.schedule, 'Hora', '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}', isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildDetailItem(Icons.access_time, 'Duración', durationText, isDark),
                      const SizedBox(height: 10),
                      _buildDetailItem(
                        Icons.attach_money,
                        amountLabel,
                        displayAmount == 0 ? 'Gratis' : '\$${displayAmount.toStringAsFixed(0)}',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment['notes'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? hintColor : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? hintColor : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? textColor : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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