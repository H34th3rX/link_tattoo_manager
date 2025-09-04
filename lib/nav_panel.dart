import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_provider.dart';
import './l10n/app_localizations.dart';
import 'services/auth_service.dart';
import '../integrations/employee_service.dart';

// Duración constante para las animaciones de transición del tema general
const Duration themeAnimationDuration = Duration(milliseconds: 300);
// Nueva duración más corta para la animación del botón de alternar tema
const Duration buttonAnimationDuration = Duration(milliseconds: 150);

//[-------------PANEL DE NAVEGACIÓN--------------]
class NavPanel extends StatefulWidget {
  final User user; // Objeto de usuario autenticado
  final VoidCallback onLogout; // Callback para cerrar sesión
  final String userName; // Nombre de usuario a mostrar

  const NavPanel({super.key, required this.user, required this.onLogout, required this.userName});

  @override
  State<NavPanel> createState() => _NavPanelState();
}

class _NavPanelState extends State<NavPanel> with TickerProviderStateMixin {
  // Controladores de animación para efectos de hover y pulso
  late AnimationController _hoverController;
  late AnimationController _pulseController;
  int _hoveredIndex = -1; // Índice del elemento con hover
  
  // Variables para manejo de imagen de perfil
  String? _cachedPhotoUrl;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    // Inicializa el controlador para animaciones de hover
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    // Inicializa el controlador para efecto de pulso en el header
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Cargar el perfil del empleado
    _loadEmployeeProfile();
  }

  @override
  void dispose() {
    // Libera los controladores de animación
    _hoverController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeeProfile() async {
    try {
      final profile = await EmployeeService.getCurrentEmployeeProfile();
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = profile?['photo_url'] as String?;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = null;
          _isLoadingProfile = false;
        });
      }
    }
  }

  //[-------------CONSTRUCCIÓN DEL PANEL--------------]
  @override
  Widget build(BuildContext context) {
    final String current = ModalRoute.of(context)?.settings.name ?? '';
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    const ui.Color primaryAccent = ui.Color(0xFFBDA206);
    const ui.Color secondaryAccent = ui.Color(0xFF00D4FF);

    return AnimatedContainer(
      duration: themeAnimationDuration,
      decoration: BoxDecoration(
        // Gradiente dinámico según el tema (oscuro o claro)
        gradient: themeProvider.isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF1A1A1A),
                  Color(0xFF000000),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F9FA),
                  Color(0xFFE9ECEF),
                  Color(0xFFDEE2E6),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: themeProvider.isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildModernHeader(themeProvider, primaryAccent),
          Expanded(
            child: _buildNavigationList(current, theme, themeProvider, primaryAccent, secondaryAccent),
          ),
          _buildBottomSection(theme, themeProvider, primaryAccent),
        ],
      ),
    );
  }

  //[-------------ENCABEZADO DEL PANEL--------------]
  // Construye el encabezado con el avatar animado y datos del usuario
  Widget _buildModernHeader(ThemeProvider themeProvider, ui.Color accent) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeProvider.isDark ? [
            const Color(0xFFBDA206),
            const Color(0xFF8B7505),
            const Color(0xFF3A3A3A),
          ] : [
            accent,
            accent.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildProfileAvatar(accent),
          const SizedBox(height: 16),
          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.user.email!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(ui.Color accent) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3 + 0.2 * _pulseController.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                // Fondo por defecto que siempre está presente
                _buildFallbackAvatar(accent),
                // Imagen que aparece encima con fade (solo si está cargando o hay imagen)
                if (_isLoadingProfile)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                  )
                else if (_cachedPhotoUrl != null && _cachedPhotoUrl!.isNotEmpty)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 500),
                    opacity: 1.0,
                    child: Image.network(
                      _cachedPhotoUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink(); // No mostrar nada si hay error, se verá el fondo
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child; // Imagen completamente cargada
                        }
                        return const SizedBox.shrink(); // Mientras carga, no mostrar nada
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(ui.Color accent) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Colors.white, Color(0xFFF0F0F0)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.user.email![0].toUpperCase(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ),
    );
  }

  //[-------------LISTA DE NAVEGACIÓN--------------]
  // Construye la lista de opciones de navegación con efectos de hover y selección
  Widget _buildNavigationList(String current, ThemeData theme, ThemeProvider themeProvider, ui.Color primaryAccent, ui.Color secondaryAccent) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    final navItems = [
      {'icon': Icons.dashboard_rounded, 'label': localizations.dashboard, 'route': '/dashboard'},
      {'icon': Icons.event_available_rounded, 'label': localizations.appointments, 'route': '/appointments'},
      {'icon': Icons.calendar_month_rounded, 'label': localizations.calendar, 'route': '/calendar'},
      {'icon': Icons.people_rounded, 'label': localizations.clients, 'route': '/clients'},
      {'icon': Icons.picture_as_pdf_rounded, 'label': localizations.reports, 'route': '/reports'},
      {'icon': Icons.person_rounded, 'label': localizations.myProfile, 'route': '/profile'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final item = navItems[index];
        final isSelected = current == item['route'];
        final isHovered = _hoveredIndex == index;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MouseRegion(
            onEnter: (_) {
              setState(() => _hoveredIndex = index);
              _hoverController.forward();
            },
            onExit: (_) {
              setState(() => _hoveredIndex = -1);
              _hoverController.reverse();
            },
            child: AnimatedContainer(
              duration: themeAnimationDuration,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? LinearGradient(
                        colors: themeProvider.isDark ? [
                          const Color(0xFFBDA206).withValues(alpha: 0.3),
                          const Color(0xFF3A3A3A).withValues(alpha: 0.2),
                        ] : [
                          primaryAccent.withValues(alpha: 0.2),
                          secondaryAccent.withValues(alpha: 0.1),
                        ],
                      )
                    : isHovered
                        ? LinearGradient(
                            colors: themeProvider.isDark ? [
                              const Color(0xFFBDA206).withValues(alpha: 0.15),
                              Colors.transparent,
                            ] : [
                              primaryAccent.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          )
                        : null,
                border: isSelected
                    ? Border.all(color: primaryAccent.withValues(alpha: 0.5), width: 1)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: AnimatedContainer(
                  duration: themeAnimationDuration,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryAccent.withValues(alpha: 0.2)
                        : isHovered
                            ? primaryAccent.withValues(alpha: 0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: isSelected
                        ? primaryAccent
                        : themeProvider.isDark
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ),
                title: AnimatedDefaultTextStyle(
                  duration: themeAnimationDuration,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? primaryAccent
                        : themeProvider.isDark
                            ? Colors.white
                            : Colors.black87,
                    fontSize: 16,
                  ),
                  child: Text(item['label'] as String),
                ),
                trailing: isSelected
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: primaryAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(context).pushReplacementNamed(item['route'] as String),
              ),
            ),
          ),
        );
      },
    );
  }

  //[-------------SECCIÓN INFERIOR--------------]
  // Construye la sección inferior con el interruptor de tema y botón de logout
  Widget _buildBottomSection(ThemeData theme, ThemeProvider themeProvider, ui.Color accent) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: themeProvider.isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildThemeSwitcher(theme, themeProvider, accent),
          const SizedBox(height: 8),
          _buildLogoutButton(accent),
        ],
      ),
    );
  }

  // Interruptor para cambiar entre modo oscuro y claro
  Widget _buildThemeSwitcher(ThemeData theme, ThemeProvider themeProvider, ui.Color accent) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: themeProvider.isDark
            ? Colors.grey[800]!.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: themeProvider.isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: themeAnimationDuration,
            style: TextStyle(
              color: themeProvider.isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            child: Text(localizations.darkMode),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => themeProvider.toggle(),
            child: AnimatedContainer(
              duration: buttonAnimationDuration, // Usar la duración más corta aquí
              width: 50,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: themeProvider.isDark
                    ? const LinearGradient(colors: [Color(0xFFBDA206), Color(0xFF3A3A3A)])
                    : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: buttonAnimationDuration, // Usar la duración más corta aquí
                    left: themeProvider.isDark ? 26 : 2,
                    top: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Botón para cerrar sesión
  Widget _buildLogoutButton(ui.Color accent) {
    final AppLocalizations localizations = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: themeAnimationDuration,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade400,
            Colors.red.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleLogout(), // Usar método específico
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  localizations.logout,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// Método específico para manejar logout correctamente
Future<void> _handleLogout() async {
  // Verificar si el widget sigue montado antes de cualquier operación UI
  if (!mounted) return;
  
  try {
    if (kDebugMode) {
      print('Iniciando proceso de logout...');
    }
    
    // Usar el método de logout mejorado del AuthService
    await AuthService.signOut();
    
    if (kDebugMode) {
      print('Logout completado, redirigiendo...');
    }
    
    // Esperar un momento para asegurar que el logout se complete
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Verificar nuevamente si el widget sigue montado antes de navegar
    if (mounted) {
      // Navegar a login con limpieza completa
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false, // Eliminar todas las rutas anteriores
      );
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error durante logout: $e');
    }
    
    // En caso de error, forzar logout básico
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (basicLogoutError) {
      if (kDebugMode) {
        print('Error en logout básico: $basicLogoutError');
      }
    }
    
    // Proceder con navegación de todas formas, pero solo si el widget sigue montado
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    }
  }
}

  // Método público para refrescar el perfil (útil cuando se actualiza la foto)
  void refreshProfile() {
    _loadEmployeeProfile();
  }
}