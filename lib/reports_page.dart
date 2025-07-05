import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';


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

// [------------- DATOS FICTICIOS PARA REPORTES --------------]
// Lista de reportes simulados con diferentes tipos y parámetros.
final List<Map<String, dynamic>> _mockReports = [
  {
    'id': '1',
    'title': 'Reporte de Clientes Activos (Julio)',
    'type': 'clients',
    'date': '2025-07-01',
    'parameters': {'include_disabled': false, 'min_clients': 0, 'status_filter': 'active'},
    'summary': '5 clientes activos, 2 nuevos este mes.',
  },
  {
    'id': '2',
    'title': 'Ingresos del Mes (Junio)',
    'type': 'financial',
    'date': '2025-06-30',
    'parameters': {'month': 'June', 'year': 2025},
    'summary': 'Ingresos totales: \$2500.00, 15 transacciones.',
  },
  {
    'id': '3',
    'title': 'Actividad Semanal (Tatuajes)',
    'type': 'services',
    'date': '2025-07-07',
    'parameters': {'service_type': 'Tatuaje'},
    'summary': '8 tatuajes realizados, 3 retoques.',
  },
  {
    'id': '4',
    'title': 'Reporte de Clientes Inactivos',
    'type': 'clients',
    'date': '2025-06-15',
    'parameters': {'include_disabled': true, 'status_filter': 'inactive'},
    'summary': '3 clientes inactivos, 1 reactivado.',
  },
  {
    'id': '5',
    'title': 'Citas Canceladas por Mes (Mayo)',
    'type': 'appointments',
    'date': '2025-05-31',
    'parameters': {'status': 'cancelled', 'month': 'May'},
    'summary': '4 citas canceladas, 2 reagendadas.',
  },
  {
    'id': '6',
    'title': 'Reporte de Piercings Realizados',
    'type': 'services',
    'date': '2025-07-08',
    'parameters': {'service_type': 'Piercing'},
    'summary': '10 piercings realizados, 2 con complicaciones menores.',
  },
  {
    'id': '7',
    'title': 'Ingresos por Servicio (Q2 2025)',
    'type': 'financial',
    'date': '2025-06-30',
    'parameters': {'quarter': 'Q2', 'year': 2025},
    'summary': 'Tatuajes: \$5000, Piercings: \$1200, Retoques: \$800.',
  },
];

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
  List<Map<String, dynamic>> _reports = []; // Lista de reportes mostrados
  List<Map<String, dynamic>> _allReports = _mockReports; // Todos los reportes disponibles

  // [------------- ESTADOS DE FILTRO DE REPORTES --------------]
  String _selectedReportType = 'all'; // 'all', 'clients', 'financial', 'services', 'appointments'
  bool _includeDisabledClients = false; // Para reportes de clientes
  int _minClientCount = 0; // Para reportes de clientes
  String _selectedServiceType = 'all'; // Para reportes de servicios
  String _selectedMonth = 'all'; // Para reportes financieros/citas

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
    _filterReports(); // Aplicar filtros iniciales
  }

  @override
  void dispose() {
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  // [------------- CARGA DE DATOS DE USUARIO --------------]
  // Obtiene el nombre de usuario del empleado desde Supabase.
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

  // [------------- FILTRADO DE REPORTES --------------]
  // Aplica los filtros seleccionados a la lista de reportes.
  void _filterReports() {
    List<Map<String, dynamic>> tempFilteredReports = _allReports.where((report) {
      bool matchesType = _selectedReportType == 'all' || report['type'] == _selectedReportType;
      bool matchesClientFilters = true;
      bool matchesServiceFilters = true;
      bool matchesFinancialFilters = true;

      // Filtros específicos para reportes de clientes
      if (report['type'] == 'clients') {
        if (!_includeDisabledClients && report['parameters']['status_filter'] == 'inactive') {
          matchesClientFilters = false;
        }
        // Simulación de filtro por cantidad de clientes (si el reporte lo tuviera)
        // if (report['parameters']['client_count'] != null && report['parameters']['client_count'] < _minClientCount) {
        //   matchesClientFilters = false;
        // }
      }

      // Filtros específicos para reportes de servicios
      if (report['type'] == 'services') {
        if (_selectedServiceType != 'all' && report['parameters']['service_type'] != _selectedServiceType) {
          matchesServiceFilters = false;
        }
      }

      // Filtros específicos para reportes financieros/citas por mes
      if ((report['type'] == 'financial' || report['type'] == 'appointments') && _selectedMonth != 'all') {
        if (report['parameters']['month'] != null && report['parameters']['month'].toLowerCase() != _selectedMonth.toLowerCase()) {
          matchesFinancialFilters = false;
        }
      }

      return matchesType && matchesClientFilters && matchesServiceFilters && matchesFinancialFilters;
    }).toList();

    setState(() {
      _reports = tempFilteredReports;
    });
  }

  // [------------- GESTIÓN DE MENSAJES DE ESTADO --------------]
  // Muestra un mensaje de error temporal.
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

  // Muestra un mensaje de éxito temporal.
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
  // Cierra la sesión del usuario y navega a la página de inicio de sesión.
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
  // Abre un bottom sheet para mostrar notificaciones.
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationsBottomSheet(),
    );
  }

  // [------------- GENERACIÓN DE NUEVO REPORTE (SIMULADA) --------------]
  // Abre un diálogo para configurar y "generar" un nuevo reporte.
  void _generateNewReport() {
    showDialog(
      context: context,
      builder: (context) {
        final bool isWide = MediaQuery.of(context).size.width >= 800;
        return ReportGenerationDialog(
          isDark: Provider.of<ThemeProvider>(context, listen: false).isDark,
          isWide: isWide, // Pasar el estado isWide al diálogo
          onGenerate: (reportType, includeDisabled, minClients, serviceType, month) {
            // Simula la adición de un nuevo reporte a la lista
            final newReportId = (_allReports.length + 1).toString();
            String title = '';
            String summary = '';
            Map<String, dynamic> parameters = {};

            switch (reportType) {
              case 'clients':
                title = 'Reporte de Clientes (${includeDisabled ? 'Todos' : 'Activos'})';
                summary = '${includeDisabled ? 'Todos' : 'Activos'} los clientes con más de $minClients servicios.';
                parameters = {'include_disabled': includeDisabled, 'min_clients': minClients, 'status_filter': includeDisabled ? 'all' : 'active'};
                break;
              case 'financial':
                title = 'Reporte Financiero (${month == 'all' ? 'General' : month})';
                summary = 'Resumen de ingresos y gastos para ${month == 'all' ? 'el período' : 'el mes de $month'}.';
                parameters = {'month': month, 'year': DateTime.now().year};
                break;
              case 'services':
                title = 'Reporte de Servicios (${serviceType == 'all' ? 'Todos' : serviceType})';
                summary = 'Análisis de servicios más populares para ${serviceType == 'all' ? 'todos los tipos' : serviceType}.';
                parameters = {'service_type': serviceType};
                break;
              case 'appointments':
                title = 'Reporte de Citas (${month == 'all' ? 'General' : month})';
                summary = 'Detalles de citas agendadas y canceladas para ${month == 'all' ? 'el período' : 'el mes de $month'}.';
                parameters = {'month': month, 'year': DateTime.now().year};
                break;
              default:
                title = 'Reporte Personalizado';
                summary = 'Reporte generado con opciones personalizadas.';
                parameters = {};
                break;
            }

            setState(() {
              _allReports.add({
                'id': newReportId,
                'title': title,
                'type': reportType,
                'date': DateTime.now().toIso8601String().substring(0, 10),
                'parameters': parameters,
                'summary': summary,
              });
              _filterReports(); // Re-filtrar para incluir el nuevo reporte
            });
            _showSuccess('Reporte "$title" generado exitosamente.');
          },
        );
      },
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
              // [------------- FONDO BLURRED --------------]
              // Fondo con efecto de desenfoque para un diseño moderno.
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
              // Los mensajes de error/éxito ahora se manejan dentro de _buildMainContent
            ],
          ),
        );
      },
    );
  }

  // [------------- CONSTRUCCIÓN DEL CONTENIDO PRINCIPAL --------------]
  // Define la estructura principal de la página de reportes, incluyendo los mensajes de estado.
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
                    // [------------- ENCABEZADO DE REPORTES --------------]
                    // Título, subtítulo y botón para generar nuevo reporte.
                    _buildHeader(isDark),
                    const SizedBox(height: 16),
                    // [------------- FILTROS DE REPORTES --------------]
                    // Dropdowns y checkboxes para filtrar la lista de reportes.
                    _buildReportFilters(isDark),
                    const SizedBox(height: 24),
                    // [------------- LISTA DE REPORTES --------------]
                    // Muestra las tarjetas de reportes filtrados.
                    _buildReportsList(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
        // [------------- MENSAJES DE ESTADO (ERROR/ÉXITO) --------------]
        // Muestra mensajes de error o éxito en la parte inferior del contenedor principal.
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
                    margin: const EdgeInsets.symmetric(horizontal: 16), // Margen para pantallas pequeñas
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
                    margin: const EdgeInsets.symmetric(horizontal: 16), // Margen para pantallas pequeñas
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
    );
  }

  // Construye el encabezado de la página de reportes.
  Widget _buildHeader(bool isDark) {
    return Row(
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
              child: const Text('Reportes'),
            ),
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? hintColor : Colors.grey[600],
              ),
              child: Text('${_reports.length} reportes disponibles'),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _generateNewReport, // Abre el diálogo de generación
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            'Generar Reporte',
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
    );
  }

  // [------------- CONSTRUCCIÓN DE FILTROS DE REPORTES --------------]
  // Crea los controles de UI para filtrar los reportes.
  Widget _buildReportFilters(bool isDark) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
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
            'Filtrar Reportes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Dropdown para tipo de reporte
          DropdownButtonFormField<String>(
            value: _selectedReportType,
            decoration: _buildInputDecoration('Tipo de Reporte', Icons.category, isDark, isDropdown: true),
            dropdownColor: isDark ? Colors.grey[800] : Colors.white,
            style: TextStyle(color: isDark ? textColor : Colors.black87),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Todos los Tipos')),
              DropdownMenuItem(value: 'clients', child: Text('Clientes')),
              DropdownMenuItem(value: 'financial', child: Text('Financieros')),
              DropdownMenuItem(value: 'services', child: Text('Servicios')),
              DropdownMenuItem(value: 'appointments', child: Text('Citas')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedReportType = value!;
                _filterReports();
              });
            },
          ),
          const SizedBox(height: 16),
          // Filtros condicionales basados en el tipo de reporte seleccionado
          if (_selectedReportType == 'clients')
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Incluir clientes inhabilitados:',
                        style: TextStyle(color: isDark ? textColor : Colors.black87),
                      ),
                    ),
                    Switch(
                      value: _includeDisabledClients,
                      onChanged: (value) {
                        setState(() {
                          _includeDisabledClients = value;
                          _filterReports();
                        });
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _minClientCount.toString(),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? textColor : Colors.black87),
                  decoration: _buildInputDecoration('Mín. servicios por cliente', Icons.numbers, isDark),
                  onChanged: (value) {
                    setState(() {
                      _minClientCount = int.tryParse(value) ?? 0;
                      _filterReports();
                    });
                  },
                ),
              ],
            ),
          if (_selectedReportType == 'services')
            DropdownButtonFormField<String>(
              value: _selectedServiceType,
              decoration: _buildInputDecoration('Tipo de Servicio', Icons.design_services, isDark, isDropdown: true),
              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDark ? textColor : Colors.black87),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos los Servicios')),
                DropdownMenuItem(value: 'Tatuaje', child: Text('Tatuaje')),
                DropdownMenuItem(value: 'Piercing', child: Text('Piercing')),
                DropdownMenuItem(value: 'Retoque', child: Text('Retoque')),
                DropdownMenuItem(value: 'Consulta', child: Text('Consulta')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedServiceType = value!;
                  _filterReports();
                });
              },
            ),
          if (_selectedReportType == 'financial' || _selectedReportType == 'appointments')
            DropdownButtonFormField<String>(
              value: _selectedMonth,
              decoration: _buildInputDecoration('Mes', Icons.calendar_month, isDark, isDropdown: true),
              dropdownColor: isDark ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: isDark ? textColor : Colors.black87),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos los Meses')),
                DropdownMenuItem(value: 'January', child: Text('Enero')),
                DropdownMenuItem(value: 'February', child: Text('Febrero')),
                DropdownMenuItem(value: 'March', child: Text('Marzo')),
                DropdownMenuItem(value: 'April', child: Text('Abril')),
                DropdownMenuItem(value: 'May', child: Text('Mayo')),
                DropdownMenuItem(value: 'June', child: Text('Junio')),
                DropdownMenuItem(value: 'July', child: Text('Julio')),
                DropdownMenuItem(value: 'August', child: Text('Agosto')),
                DropdownMenuItem(value: 'September', child: Text('Septiembre')),
                DropdownMenuItem(value: 'October', child: Text('Octubre')),
                DropdownMenuItem(value: 'November', child: Text('Noviembre')),
                DropdownMenuItem(value: 'December', child: Text('Diciembre')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMonth = value!;
                  _filterReports();
                });
              },
            ),
        // ignore: unnecessary_null_comparison
        ].where((widget) => widget != null).toList(), // Elimina widgets nulos si no se muestran
      ),
    );
  }

  // Construye la decoración de entrada para los campos de texto/dropdowns.
  InputDecoration _buildInputDecoration(String label, IconData icon, bool isDark, {bool isDropdown = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? hintColor : Colors.grey[600],
        fontSize: 14,
      ),
      prefixIcon: isDropdown ? null : Container(
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

  // [------------- LISTA DE REPORTES --------------]
  // Muestra la lista de reportes, con mensajes para estados vacíos.
  Widget _buildReportsList(bool isDark) {
    if (_loading && _reports.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }
    if (_reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
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
                child: const Text('No hay reportes registrados'),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[500],
                ),
                child: const Text(
                  'Genera tu primer reporte para comenzar o ajusta los filtros.',
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
      onRefresh: () async {
        setState(() => _loading = true);
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _loading = false;
          _allReports = _mockReports; // Simulación de recarga de todos los reportes
          _filterReports(); // Re-aplicar filtros
        });
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return AnimatedAppearance(
            delay: index * 50,
            child: ReportCard(
              report: report,
              isDark: isDark,
              onView: () {
                _showSuccess('Reporte "${report['title']}" visualizado (simulado).');
              },
              onExport: () {
                _showSuccess('Reporte "${report['title']}" exportado (simulado).');
              },
            ),
          );
        },
      ),
    );
  }
}

// [------------- WIDGET DE TARJETA DE REPORTE --------------]
// Muestra los detalles de un reporte en formato de tarjeta.
class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isDark;
  final VoidCallback onView;
  final VoidCallback onExport; // Nuevo callback para exportar

  const ReportCard({
    super.key,
    required this.report,
    required this.isDark,
    required this.onView,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final date = report['date'] ?? 'Sin fecha';
    final title = report['title'] ?? 'Reporte sin título';
    final summary = report['summary'] ?? 'Sin resumen disponible.';

    return AnimatedContainer(
      duration: themeAnimationDuration,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
            blurRadius: isDark ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: isWide ? 48 : 44,
          height: isWide ? 48 : 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isWide ? 24 : 22),
          ),
          child: Icon(Icons.description, color: Colors.white, size: isWide ? 32 : 28),
        ),
        title: AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            color: isDark ? textColor : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: TextStyle(
                color: isDark ? hintColor : Colors.grey[600],
                fontSize: 12,
              ),
              child: Text('Fecha: $date', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: TextStyle(
                color: isDark ? hintColor : Colors.grey[500],
                fontSize: 13,
              ),
              child: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón de Ver
            ElevatedButton.icon( // Cambiado a ElevatedButton.icon
              onPressed: onView,
              icon: const Icon(Icons.visibility, size: 18, color: Colors.black), // Icono de ojo
              label: const Text('Ver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de Exportar
            ElevatedButton.icon( // Cambiado a ElevatedButton.icon
              onPressed: onExport,
              icon: const Icon(Icons.download, size: 18, color: Colors.white), // Icono de descarga
              label: const Text('Exportar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[700] : Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [------------- WIDGET DE NOTIFICACIONES --------------]
// Bottom sheet para mostrar notificaciones.
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

// [------------- WIDGET DE APARICIÓN ANIMADA --------------]
// Aplica una animación de deslizamiento y desvanecimiento a su hijo.
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

// [------------- WIDGET DE FONDO BLURRED --------------]
// Widget reutilizable para el fondo con efecto de desenfoque.
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
          // Puedes añadir un color de fondo si la imagen no cubre todo o para un efecto adicional
          // color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
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

// [------------- WIDGET DE DIÁLOGO DE GENERACIÓN DE REPORTE --------------]
// Diálogo para configurar y "generar" un nuevo reporte.
class ReportGenerationDialog extends StatefulWidget {
  final bool isDark;
  final bool isWide; // Nuevo parámetro para el centrado
  final Function(String reportType, bool includeDisabled, int minClients, String serviceType, String month) onGenerate;

  const ReportGenerationDialog({
    super.key,
    required this.isDark,
    required this.isWide, // Hacerlo requerido
    required this.onGenerate,
  });

  @override
  State<ReportGenerationDialog> createState() => _ReportGenerationDialogState();
}

class _ReportGenerationDialogState extends State<ReportGenerationDialog> {
  String _selectedReportType = 'clients'; // Tipo de reporte por defecto
  bool _includeDisabledClients = false;
  int _minClientCount = 0;
  String _selectedServiceType = 'all';
  String _selectedMonth = 'all';

  @override
  Widget build(BuildContext context) {
    final double navPanelWidth = 280; // Ancho del NavPanel
    final double horizontalMargin = widget.isWide ? navPanelWidth / 2 : 0; // Margen para centrar

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(left: horizontalMargin, right: horizontalMargin), // Aplicar margen
        constraints: const BoxConstraints(maxWidth: 500),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [------------- ENCABEZADO DEL DIÁLOGO --------------]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generar Nuevo Reporte',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? textColor : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: widget.isDark ? textColor : Colors.black87),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // [------------- SELECCIÓN DE TIPO DE REPORTE --------------]
              _buildDropdown(
                label: 'Tipo de Reporte',
                icon: Icons.category,
                value: _selectedReportType,
                items: const [
                  DropdownMenuItem(value: 'clients', child: Text('Reporte de Clientes')),
                  DropdownMenuItem(value: 'financial', child: Text('Reporte Financiero')),
                  DropdownMenuItem(value: 'services', child: Text('Reporte de Servicios')),
                  DropdownMenuItem(value: 'appointments', child: Text('Reporte de Citas')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedReportType = value!;
                    // Resetear filtros específicos al cambiar el tipo de reporte
                    _includeDisabledClients = false;
                    _minClientCount = 0;
                    _selectedServiceType = 'all';
                    _selectedMonth = 'all';
                  });
                },
              ),
              const SizedBox(height: 16),
              // [------------- FILTROS ESPECÍFICOS POR TIPO DE REPORTE --------------]
              if (_selectedReportType == 'clients')
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Incluir clientes inhabilitados:',
                            style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                          ),
                        ),
                        Switch(
                          value: _includeDisabledClients,
                          onChanged: (value) {
                            setState(() {
                              _includeDisabledClients = value;
                            });
                          },
                          activeColor: primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _minClientCount.toString(),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
                      decoration: _buildInputDecoration('Mín. servicios por cliente', Icons.group_add), // Nuevo icono
                      onChanged: (value) {
                        setState(() {
                          _minClientCount = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ],
                ),
              if (_selectedReportType == 'services')
                _buildDropdown(
                  label: 'Tipo de Servicio',
                  icon: Icons.design_services,
                  value: _selectedServiceType,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Servicios')),
                    DropdownMenuItem(value: 'Tatuaje', child: Text('Tatuaje')),
                    DropdownMenuItem(value: 'Piercing', child: Text('Piercing')),
                    DropdownMenuItem(value: 'Retoque', child: Text('Retoque')),
                    DropdownMenuItem(value: 'Consulta', child: Text('Consulta')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedServiceType = value!;
                    });
                  },
                ),
              if (_selectedReportType == 'financial' || _selectedReportType == 'appointments')
                _buildDropdown(
                  label: 'Mes',
                  icon: Icons.calendar_month,
                  value: _selectedMonth,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos los Meses')),
                    DropdownMenuItem(value: 'January', child: Text('Enero')),
                    DropdownMenuItem(value: 'February', child: Text('Febrero')),
                    DropdownMenuItem(value: 'March', child: Text('Marzo')),
                    DropdownMenuItem(value: 'April', child: Text('Abril')),
                    DropdownMenuItem(value: 'May', child: Text('Mayo')),
                    DropdownMenuItem(value: 'June', child: Text('Junio')),
                    DropdownMenuItem(value: 'July', child: Text('Julio')),
                    DropdownMenuItem(value: 'August', child: Text('Agosto')),
                    DropdownMenuItem(value: 'September', child: Text('Septiembre')),
                    DropdownMenuItem(value: 'October', child: Text('Octubre')),
                    DropdownMenuItem(value: 'November', child: Text('Noviembre')),
                    DropdownMenuItem(value: 'December', child: Text('Diciembre')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  },
                ),
              const SizedBox(height: 24),
              // [------------- BOTÓN DE GENERAR REPORTE --------------]
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onGenerate(
                      _selectedReportType,
                      _includeDisabledClients,
                      _minClientCount,
                      _selectedServiceType,
                      _selectedMonth,
                    );
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.analytics, color: Colors.black),
                  label: const Text(
                    'Generar Reporte',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper para construir DropdownButtonFormField
  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: _buildInputDecoration(label, icon, isDropdown: true),
      dropdownColor: widget.isDark ? Colors.grey[800] : Colors.white,
      style: TextStyle(color: widget.isDark ? textColor : Colors.black87),
      items: items,
      onChanged: onChanged,
    );
  }

  // Helper para construir InputDecoration
  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isDropdown = false}) {
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
      filled: true,
      fillColor: widget.isDark ? Colors.grey[800]?.withValues(alpha: 0.5) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
