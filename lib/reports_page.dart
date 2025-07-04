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

// Datos ficticios para el diseño
final List<Map<String, dynamic>> _mockReports = [
  {'title': 'Reporte de Clientes Activos', 'date': '2025-07-01'},
  {'title': 'Ingresos del Mes', 'date': '2025-06-30'},
  {'title': 'Actividad Semanal', 'date': '2025-07-02'},
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
  List<Map<String, dynamic>> _reports = _mockReports;
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
              if (_error != null)
                Positioned(
                  bottom: 20,
                  left: isWide ? 296 : 16,
                  right: 16,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_errorAnimationController),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
              if (_successMessage != null)
                Positioned(
                  bottom: 20,
                  left: isWide ? 296 : 16,
                  right: 16,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_successAnimationController),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
            ],
          ),
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
                _buildReportsList(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          onPressed: _loading ? null : () {
            _showSuccess('Reporte generado exitosamente');
          },
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            'Nuevo Reporte',
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
                  'Genera tu primer reporte para comenzar',
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
          _reports = _mockReports; // Simulación de recarga
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
                _showSuccess('Reporte visualizado');
              },
            ),
          );
        },
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isDark;
  final VoidCallback onView;

  const ReportCard({
    super.key,
    required this.report,
    required this.isDark,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final date = report['date'] ?? 'Sin fecha';
    final title = report['title'] ?? 'Reporte sin título';

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
        subtitle: AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            color: isDark ? hintColor : Colors.grey[600],
            fontSize: 12,
          ),
          child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        trailing: ElevatedButton(
          onPressed: onView,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Ver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

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