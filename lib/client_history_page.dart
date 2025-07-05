import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'appbar.dart';
import 'theme_provider.dart';

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
  late List<Map<String, dynamic>> _completeHistory;
  late Map<String, dynamic> _historyStats;
  String _selectedFilter = 'Todos';
  final List<String> _filterOptions = ['Todos', 'Completados', 'Cancelados', 'Pendientes'];
  String? _userName;
  late Future<void> _loadUserData;

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
    _initializeHistoryData();
    _loadUserData = _fetchUserData();
    _animationController.forward();
  }

  //[-------------INICIALIZACIÓN DE DATOS DEL HISTORIAL--------------]
  // Simula y calcula estadísticas del historial del cliente.
  void _initializeHistoryData() {
    _completeHistory = [
      {'id': '1', 'type': 'Tatuaje', 'name': 'Rosa en el antebrazo', 'artist': 'Carlos Mendoza', 'date': '2024-01-15', 'price': 250, 'status': 'Completado', 'duration': '3 horas', 'notes': 'Cliente muy satisfecho con el resultado. Cicatrización perfecta.'},
      {'id': '2', 'type': 'Tatuaje', 'name': 'Mariposa en el hombro', 'artist': 'Ana Ruiz', 'date': '2023-08-22', 'price': 180, 'status': 'Completado', 'duration': '2.5 horas', 'notes': 'Diseño personalizado. Cliente regresó para retoque menor.'},
      {'id': '3', 'type': 'Consulta', 'name': 'Consulta inicial - Diseño espalda', 'artist': 'Miguel Torres', 'date': '2023-06-10', 'price': 0, 'status': 'Completado', 'duration': '1 hora', 'notes': 'Discusión sobre diseño complejo para la espalda. Presupuesto: \$800.'},
      {'id': '4', 'type': 'Cita', 'name': 'Dragón en la espalda - Sesión 1', 'artist': 'Miguel Torres', 'date': '2024-03-15', 'price': 400, 'status': 'Pendiente', 'duration': '4 horas', 'notes': 'Primera sesión del diseño grande. Se requieren 3 sesiones más.'},
      {'id': '5', 'type': 'Tatuaje', 'name': 'Símbolo en la muñeca', 'artist': 'Carlos Mendoza', 'date': '2023-03-20', 'price': 120, 'status': 'Cancelado', 'duration': '1 hora', 'notes': 'Cliente canceló por motivos personales. Depósito reembolsado.'},
      {'id': '6', 'type': 'Retoque', 'name': 'Retoque mariposa', 'artist': 'Ana Ruiz', 'date': '2023-09-15', 'price': 0, 'status': 'Completado', 'duration': '30 min', 'notes': 'Retoque gratuito incluido en garantía.'},
    ];
    _historyStats = {
      'total_sessions': _completeHistory.length,
      'completed': _completeHistory.where((item) => item['status'] == 'Completado').length,
      'pending': _completeHistory.where((item) => item['status'] == 'Pendiente').length,
      'cancelled': _completeHistory.where((item) => item['status'] == 'Cancelado').length,
      'total_spent': _completeHistory.where((item) => item['status'] == 'Completado').fold(0, (sum, item) => sum + (item['price'] as int)),
    };
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
      case 'completado': return successColor;
      case 'pendiente': return warningColor;
      case 'cancelado': return errorColor;
      default: return infoColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tatuaje': return Icons.brush;
      case 'consulta': return Icons.chat;
      case 'retoque': return Icons.build;
      case 'cita': return Icons.event;
      default: return Icons.circle;
    }
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    if (_selectedFilter == 'Todos') return _completeHistory;
    return _completeHistory.where((item) {
      switch (_selectedFilter) {
        case 'Completados': return item['status'] == 'Completado';
        case 'Cancelados': return item['status'] == 'Cancelado';
        case 'Pendientes': return item['status'] == 'Pendiente';
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

  Widget _buildHistoryStatsCards(bool isDark, bool isWide) {
    return isWide
        ? Row(
            children: [
              Expanded(child: _buildStatCard('${_historyStats['total_sessions']}', 'Total Sesiones', Icons.event_note, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('${_historyStats['completed']}', 'Completadas', Icons.check_circle, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('${_historyStats['pending']}', 'Pendientes', Icons.schedule, isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('\$${_historyStats['total_spent']}', 'Total Gastado', Icons.attach_money, isDark)),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_historyStats['total_sessions']}', 'Total Sesiones', Icons.event_note, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('${_historyStats['completed']}', 'Completadas', Icons.check_circle, isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('${_historyStats['pending']}', 'Pendientes', Icons.schedule, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('\$${_historyStats['total_spent']}', 'Total Gastado', Icons.attach_money, isDark)),
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
    final typeIcon = _getTypeIcon(item['type']);
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
                      Text(item['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? textColor : Colors.black87)),
                      Text(item['type'], style: TextStyle(fontSize: 12, color: isDark ? hintColor : Colors.grey[600], fontWeight: FontWeight.w500)),
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
                  child: Text(item['status'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            isWide
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDetailItem(Icons.person, 'Artista', item['artist'], isDark)),
                          Expanded(child: _buildDetailItem(Icons.calendar_today, 'Fecha', _formatDate(item['date']), isDark)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDetailItem(Icons.access_time, 'Duración', item['duration'], isDark)),
                          Expanded(child: _buildDetailItem(Icons.attach_money, 'Precio', item['price'] == 0 ? 'Gratis' : '\$${item['price']}', isDark)),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildDetailItem(Icons.person, 'Artista', item['artist'], isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.calendar_today, 'Fecha', _formatDate(item['date']), isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.access_time, 'Duración', item['duration'], isDark),
                      const SizedBox(height: 12),
                      _buildDetailItem(Icons.attach_money, 'Precio', item['price'] == 0 ? 'Gratis' : '\$${item['price']}', isDark),
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