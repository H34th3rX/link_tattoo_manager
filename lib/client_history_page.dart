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
const Color warningColor = Color(0xFFFF9800);
const Color infoColor = Color(0xFF2196F3);
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class ClientHistoryPage extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientHistoryPage({super.key, required this.client});

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Map<String, dynamic>>? _completeHistory;
  Map<String, dynamic>? _historyStats;
  String _selectedFilter = 'Todos';
  final List<String> _filterOptions = ['Todos', 'Completadas', 'Canceladas', 'Pendientes', 'Confirmadas'];
  String? _userName;
  late Future<void> _loadUserData;
  bool _isLoading = true;
  String? _errorMessage;

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
    _loadHistoryData();
    _loadUserData = _fetchUserData();
    _animationController.forward();
  }

  //[-------------CARGA DE DATOS REALES DEL HISTORIAL--------------]
  Future<void> _loadHistoryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = Supabase.instance.client.auth.currentUser!;
      final clientId = widget.client['id'] as String;

      // Get all appointments for this client
      final allAppointments = await AppointmentsService.getFilteredAppointments(
        employeeId: user.id,
        status: null, // Get all appointments regardless of status
      );

      // Filter appointments for this specific client
      final clientAppointments = allAppointments.where((apt) => apt['client_id'] == clientId).toList();

      // Sort by date (most recent first)
      clientAppointments.sort((a, b) => DateTime.parse(b['start_time']).compareTo(DateTime.parse(a['start_time'])));

      // Calculate statistics
      final completed = clientAppointments.where((item) => item['status'] == 'completa').toList();
      final pending = clientAppointments.where((item) => item['status'] == 'pendiente').toList();
      final confirmed = clientAppointments.where((item) => item['status'] == 'confirmada').toList();
      final cancelled = clientAppointments.where((item) => item['status'] == 'cancelada').toList();
      
      double totalSpent = 0.0;
      for (final appointment in completed) {
        final price = appointment['price'];
        if (price != null) {
          totalSpent += (price as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _completeHistory = clientAppointments;
          _historyStats = {
            'total_sessions': clientAppointments.length,
            'completed': completed.length,
            'pending': pending.length,
            'confirmed': confirmed.length,
            'cancelled': cancelled.length,
            'total_spent': totalSpent,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar historial del cliente: $e';
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
      // Implementar logging o mensaje al usuario.
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Implementar logging o mensaje al usuario.
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return successColor;
      case 'pendiente': return warningColor;
      case 'confirmada': return infoColor;
      case 'cancelada': return errorColor;
      default: return infoColor;
    }
  }

  IconData _getTypeIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return Icons.check_circle;
      case 'pendiente': return Icons.schedule;
      case 'confirmada': return Icons.event_available;
      case 'cancelada': return Icons.cancel;
      default: return Icons.event;
    }
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    if (_completeHistory == null) return [];
    if (_selectedFilter == 'Todos') return _completeHistory!;
    return _completeHistory!.where((item) {
      switch (_selectedFilter) {
        case 'Completadas': return item['status'] == 'completa';
        case 'Canceladas': return item['status'] == 'cancelada';
        case 'Pendientes': return item['status'] == 'pendiente';
        case 'Confirmadas': return item['status'] == 'confirmada';
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
            title: 'Historial Completo',
            onNotificationPressed: () {},
            isWide: isWide,
            showBackButton: true, // Mostrar botón de retroceso
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

  //[-------------CONSTRUCCIÓN DEL CONTENIDO PRINCIPAL--------------]
  Widget _buildMainContent(bool isDark, bool isWide) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text('Cargando historial del cliente...', style: TextStyle(color: primaryColor)),
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
              onPressed: _loadHistoryData,
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
                _buildClientSummaryCard(isDark),
                const SizedBox(height: 16),
                _buildHistoryStatsCards(isDark, isWide),
                const SizedBox(height: 24),
                _buildFilterSection(isDark),
                const SizedBox(height: 16),
                _buildHistoryList(isDark, isWide),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientSummaryCard(bool isDark) {
    final clientName = widget.client['name'] as String? ?? 'Cliente';
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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
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
                style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial de $clientName', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
                const SizedBox(height: 4),
                Text('Registro completo de servicios y citas', style: TextStyle(fontSize: 14, color: isDark ? hintColor : Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //[-------------CONSTRUCCIÓN DE TARJETAS DE ESTADÍSTICAS--------------]
  Widget _buildHistoryStatsCards(bool isDark, bool isWide) {
    if (_historyStats == null) return const SizedBox.shrink();
    
    return isWide
        ? Row(
            children: [
              Expanded(child: _buildStatCard('${_historyStats!['total_sessions']}', 'Total Sesiones', Icons.event_note, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('${_historyStats!['completed']}', 'Completadas', Icons.check_circle, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('${_historyStats!['pending'] + _historyStats!['confirmed']}', 'Pendientes', Icons.schedule, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('\$${_historyStats!['total_spent'].toStringAsFixed(0)}', 'Total Gastado', Icons.attach_money, isDark)),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_historyStats!['total_sessions']}', 'Total Sesiones', Icons.event_note, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('${_historyStats!['completed']}', 'Completadas', Icons.check_circle, isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_historyStats!['pending'] + _historyStats!['confirmed']}', 'Pendientes', Icons.schedule, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('\$${_historyStats!['total_spent'].toStringAsFixed(0)}', 'Total Gastado', Icons.attach_money, isDark)),
                ],
              ),
            ],
          );
  }

  Widget _buildStatCard(String value, String label, IconData icon, bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor), softWrap: false, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? hintColor : Colors.grey[700], fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filtrar por Estado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _selectedFilter = filter),
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  selectedColor: primaryColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: isSelected ? primaryColor : (isDark ? textColor : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  side: BorderSide(color: isSelected ? primaryColor : (isDark ? Colors.grey[600]! : Colors.grey[400]!), width: 1),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(bool isDark, bool isWide) {
    final filteredHistory = _getFilteredHistory();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial (${filteredHistory.length} registros)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredHistory.length,
          itemBuilder: (context, index) {
            final item = filteredHistory[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildHistoryCard(item, isDark, isWide),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, bool isDark, bool isWide) {
    final statusColor = _getStatusColor(item['status']);
    final typeIcon = _getTypeIcon(item['status']);
    final startTime = DateTime.parse(item['start_time']);
    final endTime = DateTime.parse(item['end_time']);
    final duration = endTime.difference(startTime);
    final durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
    final price = item['price'] ?? 0;
    final description = item['description'] ?? 'Cita';
    
    return AnimatedContainer(
      duration: themeAnimationDuration,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(typeIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
                      Text('Cita', style: TextStyle(fontSize: 12, color: isDark ? hintColor : Colors.grey[600], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Text(_getStatusDisplayName(item['status']), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isWide
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDetailItem(Icons.calendar_today, 'Fecha', _formatDate(item['start_time']), isDark)),
                          Expanded(child: _buildDetailItem(Icons.access_time, 'Duración', durationText, isDark)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDetailItem(Icons.schedule, 'Hora', '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}', isDark)),
                          Expanded(child: _buildDetailItem(Icons.attach_money, 'Precio', price == 0 ? 'Gratis' : '\$${price.toStringAsFixed(0)}', isDark)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildDetailItem(Icons.calendar_today, 'Fecha', _formatDate(item['start_time']), isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.schedule, 'Hora', '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}', isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.access_time, 'Duración', durationText, isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.attach_money, 'Precio', price == 0 ? 'Gratis' : '\$${price.toStringAsFixed(0)}', isDark),
                    ],
                  ),
            if (item['notes'] != null && item['notes'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notas:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(item['notes'], style: TextStyle(fontSize: 14, color: isDark ? hintColor : Colors.grey[700])),
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
        Icon(icon, size: 16, color: primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? hintColor : Colors.grey[600], fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 14, color: isDark ? textColor : Colors.black87, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'completa': return 'Completada';
      case 'pendiente': return 'Pendiente';
      case 'confirmada': return 'Confirmada';
      case 'cancelada': return 'Cancelada';
      default: return status;
    }
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
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/logo.png'), fit: BoxFit.cover)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: themeAnimationDuration,
            color: isDark ? const Color.fromRGBO(0, 0, 0, 0.7) : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}