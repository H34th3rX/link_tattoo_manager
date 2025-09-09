import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import './integrations/reports_service.dart'; // Importar el nuevo servicio

// Constantes globales para la página de reportes
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with TickerProviderStateMixin {
  String? _userName;
  late Future<void> _loadUserData;
  bool _loading = false;
  String? _error;
  String? _successMessage;

  // [------------- ESTADOS DE FILTRO DE REPORTES --------------]
  String _selectedReportType = 'financial'; // Tipo por defecto
  String _selectedPeriod = 'monthly'; // 'weekly', 'monthly', 'yearly', 'custom'
  bool _includeInactiveClients = false;
  int _minAppointments = 0;
  String _appointmentStatus = 'all';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

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
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  // [------------- CARGA DE DATOS DE USUARIO --------------]
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

  // [------------- GESTIÓN DE MENSAJES DE ESTADO --------------]
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

  // ignore: unused_element
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

  // [------------- LÓGICA DE CIERRE DE SESIÓN --------------]
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

  // [------------- GESTIÓN DE NOTIFICACIONES --------------]
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationsBottomSheet(),
    );
  }

  // [------------- GENERACIÓN DE REPORTE --------------]
  Future<void> _generateReport() async {
    final user = Supabase.instance.client.auth.currentUser!;
    
    setState(() => _loading = true);
    
    try {
      Map<String, dynamic> reportData;
      String reportTitle;
      
      // Determinar fechas para período personalizado
      DateTime? startDate = _customStartDate;
      DateTime? endDate = _customEndDate;
      
      if (_selectedPeriod == 'custom' && (startDate == null || endDate == null)) {
        _showError('Selecciona un rango de fechas válido para el período personalizado');
        return;
      }

      switch (_selectedReportType) {
        case 'financial':
          reportData = await ReportsService.getFinancialReport(
            employeeId: user.id,
            period: _selectedPeriod,
            startDate: startDate,
            endDate: endDate,
          );
          reportTitle = 'Reporte Financiero';
          break;
          
        case 'clients':
          reportData = await ReportsService.getClientsReport(
            employeeId: user.id,
            includeInactive: _includeInactiveClients,
            minAppointments: _minAppointments,
          );
          reportTitle = 'Reporte de Clientes';
          break;
          
        case 'appointments':
          reportData = await ReportsService.getAppointmentsReport(
            employeeId: user.id,
            period: _selectedPeriod,
            status: _appointmentStatus == 'all' ? null : _appointmentStatus,
            startDate: startDate,
            endDate: endDate,
          );
          reportTitle = 'Reporte de Citas';
          break;
          
        case 'services':
          reportData = await ReportsService.getServicesReport(
            employeeId: user.id,
            period: _selectedPeriod,
            startDate: startDate,
            endDate: endDate,
          );
          reportTitle = 'Reporte de Servicios';
          break;
          
        default:
          throw Exception('Tipo de reporte no válido');
      }
      
      // Mostrar popup con el reporte
      if (mounted) {
        _showReportPopup(reportTitle, reportData);
      }
      
    } catch (e) {
      _showError('Error al generar el reporte: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // [------------- MOSTRAR POPUP DEL REPORTE --------------]
  void _showReportPopup(String title, Map<String, dynamic> data) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => ReportPopup(
        title: title,
        data: data,
        reportType: _selectedReportType,
        isDark: themeProvider.isDark,
        isWide: isWide,
      ),
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
        return Scaffold(
          backgroundColor: isDark ? backgroundColor : Colors.grey[100],
          appBar: CustomAppBar(
            title: 'Reportes',
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
        );
      },
    );
  }

  Widget _buildMainContent(bool isDark, bool isWide) {
    return Stack(
      children: [
        SingleChildScrollView(
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
                    _buildReportFilters(isDark),
                    const SizedBox(height: 24),
                    _buildGenerateButton(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Mensajes de estado
        if (_error != null) _buildErrorMessage(),
        if (_successMessage != null) _buildSuccessMessage(),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? textColor : Colors.black87,
          ),
          child: const Text('Reportes'),
        ),
        AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? hintColor : Colors.grey[600],
          ),
          child: const Text('Genera reportes detallados de tu negocio'),
        ),
      ],
    );
  }

  Widget _buildReportFilters(bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración del Reporte',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          
          // Tipo de reporte
          DropdownButtonFormField<String>(
            initialValue: _selectedReportType,
            decoration: _buildInputDecoration('Tipo de Reporte', Icons.analytics, isDark),
            dropdownColor: isDark ? Colors.grey[800] : Colors.white,
            style: TextStyle(color: isDark ? textColor : Colors.black87),
            items: const [
              DropdownMenuItem(value: 'financial', child: Text('Reporte Financiero')),
              DropdownMenuItem(value: 'clients', child: Text('Reporte de Clientes')),
              DropdownMenuItem(value: 'appointments', child: Text('Reporte de Citas')),
              DropdownMenuItem(value: 'services', child: Text('Reporte de Servicios')),
            ],
            onChanged: (value) => setState(() => _selectedReportType = value!),
          ),
          const SizedBox(height: 16),
          
          // Período (excepto para reporte de clientes)
          if (_selectedReportType != 'clients')
            Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedPeriod,
                  decoration: _buildInputDecoration('Período', Icons.calendar_today, isDark),
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  style: TextStyle(color: isDark ? textColor : Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                    DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                    DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                    DropdownMenuItem(value: 'custom', child: Text('Personalizado')),
                  ],
                  onChanged: (value) => setState(() => _selectedPeriod = value!),
                ),
                const SizedBox(height: 16),
              ],
            ),
            
          // Fechas personalizadas
          if (_selectedPeriod == 'custom' && _selectedReportType != 'clients')
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(
                      _customStartDate == null 
                        ? 'Fecha Inicio' 
                        : 'Inicio: ${_customStartDate!.day}/${_customStartDate!.month}/${_customStartDate!.year}',
                      style: TextStyle(color: isDark ? textColor : Colors.black87),
                    ),
                    leading: const Icon(Icons.calendar_today, color: primaryColor),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _customStartDate ?? DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _customStartDate = date);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(
                      _customEndDate == null 
                        ? 'Fecha Fin' 
                        : 'Fin: ${_customEndDate!.day}/${_customEndDate!.month}/${_customEndDate!.year}',
                      style: TextStyle(color: isDark ? textColor : Colors.black87),
                    ),
                    leading: const Icon(Icons.event, color: primaryColor),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _customEndDate ?? DateTime.now(),
                        firstDate: _customStartDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => _customEndDate = date);
                    },
                  ),
                ),
              ],
            ),
          
          // Filtros específicos por tipo de reporte
          if (_selectedReportType == 'clients') ...[
            SwitchListTile(
              title: Text(
                'Incluir clientes inactivos',
                style: TextStyle(color: isDark ? textColor : Colors.black87),
              ),
              value: _includeInactiveClients,
              onChanged: (value) => setState(() => _includeInactiveClients = value),
              activeThumbColor: primaryColor,
            ),
            TextFormField(
              initialValue: _minAppointments.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? textColor : Colors.black87),
              decoration: _buildInputDecoration('Mínimo de citas', Icons.numbers, isDark),
              onChanged: (value) => setState(() => _minAppointments = int.tryParse(value) ?? 0),
            ),
          ],
          
          if (_selectedReportType == 'appointments') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _appointmentStatus,
              decoration: _buildInputDecoration('Estado de Citas', Icons.event_note, isDark),
              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDark ? textColor : Colors.black87),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
                DropdownMenuItem(value: 'pendiente', child: Text('Pendientes')),
                DropdownMenuItem(value: 'confirmada', child: Text('Confirmadas')),
                DropdownMenuItem(value: 'completa', child: Text('Completadas')),
                DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
                DropdownMenuItem(value: 'aplazada', child: Text('Aplazadas')),
              ],
              onChanged: (value) => setState(() => _appointmentStatus = value!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerateButton(bool isDark) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _generateReport,
        icon: _loading 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Icon(Icons.analytics, color: Colors.black),
        label: Text(
          _loading ? 'Generando...' : 'Generar Reporte',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? hintColor : Colors.grey[600],
        fontSize: 14,
      ),
      prefixIcon: Container(
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
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildErrorMessage() {
    return Positioned(
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
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }

  Widget _buildSuccessMessage() {
    return Positioned(
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
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }
}

// [------------- FUNCIÓN PARA FORMATEAR PRECIOS --------------]
// ignore: unused_element
String _formatPrice(double price) {
  if (price >= 1000) {
    return '\$${(price / 1000).toStringAsFixed(1)}K';
  } else {
    return '\$${price.toStringAsFixed(0)}';
  }
}

// [------------- POPUP DE REPORTE --------------]
class ReportPopup extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  final String reportType;
  final bool isDark;
  final bool isWide;

  const ReportPopup({
    super.key,
    required this.title,
    required this.data,
    required this.reportType,
    required this.isDark,
    required this.isWide,
  });

  // Función para formatear precios
  String _formatPrice(double price) {
    if (price >= 1000) {
      return '\$${(price / 1000).toStringAsFixed(1)}K';
    } else {
      return '\$${price.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isWide ? 800 : MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header del popup
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _getSubtitle(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Contenido del reporte
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildReportContent(),
              ),
            ),
            
            // Botones de acción
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funcionalidad de exportación próximamente')),
                      );
                    },
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar PDF', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Funcionalidad de impresión próximamente')),
                      );
                    },
                    icon: const Icon(Icons.print, color: Colors.black),
                    label: const Text('Imprimir', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

   String _getSubtitle() {
    switch (reportType) {
      case 'financial':
        final period = data['period'] ?? 'N/A';
        return 'Período: ${_formatPeriod(period)}';
      case 'clients':
        return 'Total de clientes: ${data['total_clients'] ?? 0}';
      case 'appointments':
        final period = data['period'] ?? 'N/A';
        return 'Período: ${_formatPeriod(period)} - Total: ${data['total_appointments'] ?? 0} citas';
      case 'services':
        return 'Total de servicios: ${data['total_services'] ?? 0}';
      default:
        return '';
    }
  }

  String _formatPeriod(String period) {
    switch (period) {
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'yearly': return 'Anual';
      case 'custom': return 'Personalizado';
      default: return period;
    }
  }

  Widget _buildReportContent() {
    switch (reportType) {
      case 'financial':
        return _buildFinancialReport();
      case 'clients':
        return _buildClientsReport();
      case 'appointments':
        return _buildAppointmentsReport();
      case 'services':
        return _buildServicesReport();
      default:
        return const Text('Tipo de reporte no soportado');
    }
  }

  Widget _buildFinancialReport() {
    final totalRevenue = data['total_revenue'] ?? 0.0;
    final totalDeposits = data['total_deposits'] ?? 0.0;
    final pendingRevenue = data['pending_revenue'] ?? 0.0;
    final totalAppointments = data['total_appointments'] ?? 0;
    final completedAppointments = data['completed_appointments'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards([
          SummaryCardData(
            title: 'Ingresos Totales',
            value: _formatPrice(totalRevenue.toDouble()),
            icon: Icons.attach_money,
            color: Colors.green,
          ),
          SummaryCardData(
            title: 'Depósitos Recibidos',
            value: _formatPrice(totalDeposits.toDouble()),
            icon: Icons.savings,
            color: Colors.blue,
          ),
          SummaryCardData(
            title: 'Ingresos Pendientes',
            value: _formatPrice(pendingRevenue.toDouble()),
            icon: Icons.schedule,
            color: Colors.orange,
          ),
          SummaryCardData(
            title: 'Citas Completadas',
            value: '$completedAppointments/$totalAppointments',
            icon: Icons.check_circle,
            color: primaryColor,
          ),
        ]),
        
        const SizedBox(height: 24),
        
        if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
          Text(
            'Detalles de Transacciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildTransactionsList(data['appointments'] as List),
        ],
      ],
    );
  }

  Widget _buildClientsReport() {
    final totalClients = data['total_clients'] ?? 0;
    final activeClients = data['active_clients'] ?? 0;
    final inactiveClients = data['inactive_clients'] ?? 0;
    final newClientsThisMonth = data['new_clients_this_month'] ?? 0;
    final avgAppointments = data['average_appointments_per_client'] ?? '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards([
          SummaryCardData(
            title: 'Clientes Totales',
            value: totalClients.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
          SummaryCardData(
            title: 'Clientes Activos',
            value: activeClients.toString(),
            icon: Icons.person,
            color: Colors.green,
          ),
          SummaryCardData(
            title: 'Clientes Inactivos',
            value: inactiveClients.toString(),
            icon: Icons.person_off,
            color: Colors.red,
          ),
          SummaryCardData(
            title: 'Nuevos Este Mes',
            value: newClientsThisMonth.toString(),
            icon: Icons.person_add,
            color: primaryColor,
          ),
        ]),
        
        const SizedBox(height: 16),
        
        _buildInfoCard('Promedio de Citas por Cliente', avgAppointments, Icons.analytics),
        
        const SizedBox(height: 24),
        
        if (data['clients'] != null && (data['clients'] as List).isNotEmpty) ...[
          Text(
            'Lista de Clientes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildClientsList(data['clients'] as List),
        ],
      ],
    );
  }

 Widget _buildAppointmentsReport() {
    final totalAppointments = data['total_appointments'] ?? 0;
    final statusBreakdown = data['status_breakdown'] as Map<String, int>? ?? {};
    final totalRevenue = data['total_revenue'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards([
          SummaryCardData(
            title: 'Total de Citas',
            value: totalAppointments.toString(),
            icon: Icons.event,
            color: Colors.blue,
          ),
          SummaryCardData(
            title: 'Completadas',
            value: statusBreakdown['completa']?.toString() ?? '0',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          SummaryCardData(
            title: 'Canceladas',
            value: statusBreakdown['cancelada']?.toString() ?? '0',
            icon: Icons.cancel,
            color: Colors.red,
          ),
          SummaryCardData(
            title: 'Ingresos Generados',
            value: _formatPrice(totalRevenue.toDouble()),
            icon: Icons.attach_money,
            color: primaryColor,
          ),
        ]),
        
        const SizedBox(height: 24),
        
        Text(
          'Distribución por Estado',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? textColor : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatusBreakdown(statusBreakdown),
        
        const SizedBox(height: 24),
        
        if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
          Text(
            'Detalles de Citas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildAppointmentsList(data['appointments'] as List),
        ],
      ],
    );
  }

  Widget _buildServicesReport() {
    final totalServices = data['total_services'] ?? 0;
    final uniqueServices = data['unique_services'] ?? 0;
    final mostPopular = data['most_popular_service'] ?? 'N/A';
    final servicesBreakdown = data['services_breakdown'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards([
          SummaryCardData(
            title: 'Servicios Totales',
            value: totalServices.toString(),
            icon: Icons.design_services,
            color: Colors.blue,
          ),
          SummaryCardData(
            title: 'Tipos Únicos',
            value: uniqueServices.toString(),
            icon: Icons.category,
            color: Colors.green,
          ),
          SummaryCardData(
            title: 'Más Popular',
            value: mostPopular.length > 15 ? '${mostPopular.substring(0, 15)}...' : mostPopular,
            icon: Icons.star,
            color: primaryColor,
          ),
        ]),
        
        const SizedBox(height: 24),
        
        if (servicesBreakdown.isNotEmpty) ...[
          Text(
            'Desglose por Servicio',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildServicesBreakdown(servicesBreakdown),
        ],
      ],
    );
  }

 Widget _buildSummaryCards(List<SummaryCardData> cards) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        childAspectRatio: 1.2, // Cambiado de 1.5 a 1.2 para hacer las tarjetas más altas
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: card.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(card.icon, color: card.color, size: 28), // Reducido de 32 a 28
              const SizedBox(height: 8),
              Text(
                card.value,
                style: TextStyle(
                  fontSize: 16, // Reducido de 18 a 16
                  fontWeight: FontWeight.bold,
                  color: isDark ? textColor : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                card.title,
                style: TextStyle(
                  fontSize: 11, // Reducido de 12 a 11
                  color: isDark ? hintColor : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? textColor : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

 Widget _buildTransactionsList(List transactions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final startTime = DateTime.tryParse(transaction['start_time'] ?? '');
        final price = (transaction['price'] as num?)?.toDouble() ?? 0.0;
        final status = transaction['status'] ?? 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      startTime != null 
                        ? '${startTime.day}/${startTime.month}/${startTime.year}'
                        : 'Fecha N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    Text(
                      'Estado: $status',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatPrice(price),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: status == 'completa' ? Colors.green : primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientsList(List clients) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final name = client['name'] ?? 'N/A';
        final totalAppointments = client['total_appointments'] ?? 0;
        final status = client['status'] ?? false;
        final registrationDate = DateTime.tryParse(client['registration_date'] ?? '');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    Text(
                      'Citas: $totalAppointments | Registro: ${registrationDate != null ? '${registrationDate.day}/${registrationDate.month}/${registrationDate.year}' : 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? hintColor : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBreakdown(Map<String, int> statusBreakdown) {
    return Column(
      children: statusBreakdown.entries.map((entry) {
        final status = entry.key;
        final count = entry.value;
        final statusName = _getStatusName(status);
        final color = _getStatusColor(status);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    statusName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? textColor : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppointmentsList(List appointments) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final startTime = DateTime.tryParse(appointment['start_time'] ?? '');
        final description = appointment['description'] ?? 'Sin descripción';
        final status = appointment['status'] ?? 'N/A';
        final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    startTime != null 
                      ? '${startTime.day}/${startTime.month}/${startTime.year} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'
                      : 'Fecha N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? textColor : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusName(status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
              ),
              if (price > 0) ...[
                const SizedBox(height: 4),
                Text(
                  _formatPrice(price),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildServicesBreakdown(Map<String, dynamic> servicesBreakdown) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: servicesBreakdown.length,
      itemBuilder: (context, index) {
        final entry = servicesBreakdown.entries.elementAt(index);
        final serviceName = entry.key;
        final serviceData = entry.value as Map<String, dynamic>;
        final count = serviceData['count'] ?? 0;
        final totalRevenue = serviceData['total_revenue']?.toDouble() ?? 0.0;
        final averagePrice = serviceData['average_price']?.toDouble() ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      serviceName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? textColor : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$count servicios',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ingresos: ${_formatPrice(totalRevenue)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? hintColor : Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Promedio: ${_formatPrice(averagePrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? hintColor : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  String _getStatusName(String status) {
    switch (status) {
      case 'pendiente': return 'Pendiente';
      case 'confirmada': return 'Confirmada';
      case 'completa': return 'Completada';
      case 'cancelada': return 'Cancelada';
      case 'aplazada': return 'Aplazada';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente': return Colors.orange;
      case 'confirmada': return Colors.blue;
      case 'completa': return Colors.green;
      case 'cancelada': return Colors.red;
      case 'aplazada': return Colors.purple;
      default: return Colors.grey;
    }
  }
}

// [------------- CLASE DE DATOS PARA TARJETAS RESUMEN --------------]
class SummaryCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// [------------- WIDGET DE NOTIFICACIONES --------------]
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Notificaciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text('No hay notificaciones nuevas'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

// [------------- WIDGET DE FONDO BLURRED --------------]
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