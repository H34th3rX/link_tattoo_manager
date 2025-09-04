import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../integrations/employee_service.dart';
import '../services/auth_service.dart';

//[-------------PANTALLA DE CARGA ANIMADA OPTIMIZADA PARA LOGIN Y LOGOUT--------------]
class LoadingScreen extends StatefulWidget {
  final String? userName; // Nombre del usuario opcional
  final LoadingScreenType type; // Tipo de carga (login o logout)
  
  const LoadingScreen({
    super.key, 
    this.userName,
    this.type = LoadingScreenType.login,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

// Enum para definir el tipo de pantalla de carga
enum LoadingScreenType {
  login,    // Carga inicial/después de login
  logout,   // Pantalla de despedida al cerrar sesión
}

// Estado de la pantalla de carga con animaciones
class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  // Controladores de animación para diferentes efectos
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AnimationController _fadeOutController; // Para logout
  
  // Animaciones definidas
  late Animation<double> _progressAnimation;
  late Animation<double> _borderAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeOutAnimation; // Para logout

  // Timer para garantizar duración mínima
  Timer? _minimumDurationTimer;
  bool _animationCompleted = false;
  bool _minimumTimeElapsed = false;
  bool _userCheckCompleted = false;
  bool _isLogoutComplete = false;

  // Variables para el estado del usuario
  String _statusMessage = 'Iniciando...';
  String _displayName = '';
  String? _redirectRoute;
  
  // Variables para el perfil del empleado - OPTIMIZADAS
  String? _cachedPhotoUrl;
  bool _isLoadingProfile = false; // Cambio: inicia en false
// Nueva variable para control

  // Variables específicas para logout
  final List<String> _logoutMessages = [
    'Cerrando sesión...',
    'Limpiando datos...',
    'Guardando configuración...',
    '¡Hasta pronto!',
  ];
  int _currentLogoutMessageIndex = 0;
  Timer? _logoutMessageTimer;

  @override
  void initState() {
    super.initState();
    
    _initializeControllers();
    _initializeAnimations();
    
    if (widget.type == LoadingScreenType.login) {
      _handleLoginFlow();
    } else {
      _handleLogoutFlow();
    }
  }

  void _initializeControllers() {
    // Duraciones ajustables según el tipo
    final mainDuration = widget.type == LoadingScreenType.login
        ? (kDebugMode ? const Duration(seconds: 4) : const Duration(seconds: 6))
        : const Duration(seconds: 3); // Logout más rápido

    _mainController = AnimationController(duration: mainDuration, vsync: this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this,
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3), vsync: this,
    )..repeat();
    _particleController = AnimationController(
      duration: const Duration(seconds: 2), vsync: this,
    )..repeat();
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this,
    );
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this,
    );
  }

  void _initializeAnimations() {
    _progressAnimation = CurvedAnimation(
      parent: _mainController,
      curve: widget.type == LoadingScreenType.login
          ? const Interval(0.3, 1.0, curve: Curves.easeInOutCubic)
          : Curves.easeInOut,
    );
    
    _borderAnimation = CurvedAnimation(parent: _mainController, curve: Curves.easeInOut);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _rotationAnimation = CurvedAnimation(parent: _rotationController, curve: Curves.linear);
    _scaleAnimation = CurvedAnimation(parent: _textController, curve: Curves.elasticOut);
    _fadeAnimation = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOutBack));
    
    _fadeOutAnimation = CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOut);

    // Listener para manejar la finalización
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationCompleted = true;
        if (widget.type == LoadingScreenType.login) {
          _checkForRedirect();
        } else {
          _completeLogout();
        }
      }
    });
  }

  void _handleLoginFlow() {
    _statusMessage = 'Iniciando...';
    _startMinimumDurationTimer();
    _checkUserStatus();
    _loadEmployeeProfile();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mainController.forward();
        _textController.forward();
      }
    });
  }

  void _handleLogoutFlow() {
    _statusMessage = _logoutMessages[0];
    _displayName = widget.userName ?? 'Usuario';
    
    // CAMBIO PRINCIPAL: Cargar el perfil ANTES de iniciar el logout
    _loadEmployeeProfileForLogout();
    
    _startLogoutMessageCycle();
    _performLogout();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mainController.forward();
        _textController.forward();
      }
    });
  }

  // NUEVA FUNCIÓN: Cargar perfil específicamente para logout
  Future<void> _loadEmployeeProfileForLogout() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await EmployeeService.getCurrentEmployeeProfile();
        if (mounted) {
          setState(() {
            _cachedPhotoUrl = profile?['photo_url'] as String?;
            _isLoadingProfile = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cachedPhotoUrl = null;
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = null;
          _isLoadingProfile = false;
        });
      }
      if (kDebugMode) {
        print('Error al cargar perfil para logout: $e');
      }
    }
  }

  void _startLogoutMessageCycle() {
    _logoutMessageTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && _currentLogoutMessageIndex < _logoutMessages.length - 1) {
        setState(() {
          _currentLogoutMessageIndex++;
          _statusMessage = _logoutMessages[_currentLogoutMessageIndex];
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _performLogout() async {
    try {
      // Simular proceso de logout con delays realistas
      await Future.delayed(const Duration(milliseconds: 600)); // Cerrando sesión
      
      if (mounted) {
        setState(() {
          _statusMessage = _logoutMessages[1]; // Limpiando datos
        });
      }
      
      // Ejecutar logout real
      await AuthService.signOut();
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (mounted) {
        setState(() {
          _statusMessage = _logoutMessages[2]; // Guardando configuración
        });
      }
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (mounted) {
        setState(() {
          _statusMessage = _logoutMessages[3]; // ¡Hasta pronto!
        });
      }
      
      _isLogoutComplete = true;
      await Future.delayed(const Duration(milliseconds: 800));
      
    } catch (e) {
      if (kDebugMode) {
        print('Error durante logout: $e');
      }
      // Continuar con logout forzado
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      _isLogoutComplete = true;
    }
  }

  void _completeLogout() {
    if (_isLogoutComplete && mounted) {
      _fadeOutController.forward().then((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    }
  }

  // Cargar el perfil del empleado (optimizado para login)
  Future<void> _loadEmployeeProfile() async {
    if (widget.type != LoadingScreenType.login || !mounted) {
      return;
    }

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await EmployeeService.getCurrentEmployeeProfile();
        if (mounted) {
          setState(() {
            _cachedPhotoUrl = profile?['photo_url'] as String?;
            _isLoadingProfile = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cachedPhotoUrl = null;
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = null;
          _isLoadingProfile = false;
        });
      }
      if (kDebugMode) {
        print('Error al cargar perfil del empleado en loading screen: $e');
      }
    }
  }

  // Verificar el estado del usuario (solo para login)
  Future<void> _checkUserStatus() async {
    if (widget.type != LoadingScreenType.login) {
      _userCheckCompleted = true;
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Redirigiendo al login...';
            _redirectRoute = '/login';
          });
        }
        _userCheckCompleted = true;
        return;
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Verificando perfil...';
        });
      }

      // Verificar si el usuario existe en la tabla employees
      final employeeResponse = await Supabase.instance.client
          .from('employees')
          .select('id, username')
          .eq('id', user.id)
          .maybeSingle();

      if (employeeResponse != null) {
        final username = employeeResponse['username'] as String?;
        if (mounted) {
          if (username != null && username.isNotEmpty) {
            setState(() {
              _displayName = username;
              _statusMessage = 'Preparando dashboard...';
              _redirectRoute = '/dashboard';
            });
          } else {
            setState(() {
              _displayName = user.email?.split('@')[0] ?? 'Usuario';
              _statusMessage = 'Completando perfil...';
              _redirectRoute = '/complete_profile';
            });
          }
        }
        _userCheckCompleted = true;
        return;
      }

      // Verificar clientes
      final clientResponse = await Supabase.instance.client
          .from('clients')
          .select('id, name')
          .eq('email', user.email!)
          .maybeSingle();

      if (clientResponse != null) {
        final clientName = clientResponse['name'] as String?;
        if (mounted) {
          setState(() {
            _displayName = clientName ?? 'Cliente';
            _statusMessage = 'Preparando tu área...';
            _redirectRoute = '/client_dashboard';
          });
        }
        _userCheckCompleted = true;
        return;
      }

      // Usuario sin perfil específico
      final userType = user.userMetadata?['user_type'] as String?;
      
      if (mounted) {
        if (userType == 'client') {
          setState(() {
            _displayName = user.email?.split('@')[0] ?? 'Cliente';
            _statusMessage = 'Completando registro...';
            _redirectRoute = '/complete_profile';
          });
        } else {
          setState(() {
            _displayName = user.email?.split('@')[0] ?? 'Usuario';
            _statusMessage = 'Completando perfil...';
            _redirectRoute = '/complete_profile';
          });
        }
      }
      _userCheckCompleted = true;

    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al verificar usuario';
          _displayName = 'Usuario';
          _redirectRoute = '/login';
        });
      }
      
      if (kDebugMode) {
        print('Error en verificación de usuario: $e');
      }
      
      _userCheckCompleted = true;
    }
  }

  void _startMinimumDurationTimer() {
    final minimumDuration = widget.type == LoadingScreenType.login
        ? (kDebugMode ? const Duration(seconds: 3) : const Duration(seconds: 5))
        : const Duration(seconds: 2);
    
    _minimumDurationTimer = Timer(minimumDuration, () {
      _minimumTimeElapsed = true;
      if (widget.type == LoadingScreenType.login) {
        _checkForRedirect();
      }
    });
  }

  void _checkForRedirect() {
    if (_animationCompleted && _minimumTimeElapsed && _userCheckCompleted && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _redirectRoute != null) {
          Navigator.pushReplacementNamed(context, _redirectRoute!);
        }
      });
    }
  }

  @override
  void dispose() {
    _minimumDurationTimer?.cancel();
    _logoutMessageTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFFBDA206);
    const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
    const Color textColor = Colors.white;
    const Color hintColor = Colors.white70;

    final displayName = widget.userName ?? _displayName;

    return Scaffold(
      body: AnimatedBuilder(
        animation: widget.type == LoadingScreenType.logout ? _fadeOutAnimation : _mainController,
        builder: (context, child) {
          return Opacity(
            opacity: widget.type == LoadingScreenType.logout 
                ? 1.0 - _fadeOutAnimation.value 
                : 1.0,
            child: Stack(
              children: [
                // Fondo difuminado con logo
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Color.fromRGBO(0, 0, 0, 0.7),
                          BlendMode.dstATop,
                        ),
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: const Color.fromRGBO(0, 0, 0, 0.4),
                      ),
                    ),
                  ),
                ),
                
                // Partículas flotantes (optimizadas para logout)
                if (widget.type == LoadingScreenType.login)
                  ...List.generate(12, (index) => _buildFloatingParticle(index, accentColor))
                else
                  ...List.generate(8, (index) => _buildFloatingParticle(index, accentColor)), // Menos partículas en logout
                
                // Contenedor central
                Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _mainController, 
                      _pulseController, 
                      _rotationController,
                      _textController
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseAnimation.value * 0.03),
                        child: Container(
                          width: 360,
                          padding: const EdgeInsets.all(35),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.4 + (_pulseAnimation.value * 0.3)),
                                blurRadius: 40 + (_pulseAnimation.value * 15),
                                offset: const Offset(0, 20),
                              ),
                            ],
                            border: Border.all(
                              color: accentColor.withValues(alpha: _borderAnimation.value * 0.9),
                              width: 3.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar con anillos rotatorios
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  _buildRotatingRing(140, 2.5, 0.4, 2.0),
                                  _buildRotatingRing(110, 2.0, 0.6, -1.5),
                                  _buildRotatingRing(85, 1.5, 0.7, 3.0),
                                  _buildProfileImage(accentColor),
                                ],
                              ),
                              
                              const SizedBox(height: 35),
                              
                              // Texto de bienvenida/despedida
                              SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Column(
                                      children: [
                                        Text(
                                          widget.type == LoadingScreenType.login 
                                              ? '¡Bienvenido!' 
                                              : '¡Hasta pronto!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            shadows: [
                                              Shadow(
                                                color: accentColor.withValues(alpha: 0.6),
                                                blurRadius: 15,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (displayName.isNotEmpty)
                                          Text(
                                            displayName,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                              color: accentColor,
                                              shadows: [
                                                Shadow(
                                                  color: accentColor.withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 45),
                              
                              // Barra de progreso
                              _buildProgressBar(accentColor, hintColor),
                              
                              const SizedBox(height: 25),
                              
                              // Porcentaje
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return Text(
                                    '${(_progressAnimation.value * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                      shadows: [
                                        Shadow(
                                          color: accentColor.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 15),
                              
                              // Mensaje de estado
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: Text(
                                  _statusMessage,
                                  key: ValueKey(_statusMessage),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: hintColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRotatingRing(double size, double width, double alpha, double speed) {
    return Transform.rotate(
      angle: _rotationAnimation.value * speed * math.pi,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFBDA206).withValues(alpha: alpha),
            width: width,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color accentColor, Color hintColor) {
    return Stack(
      children: [
        Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hintColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        SizedBox(
          height: 14,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.7),
                    accentColor,
                    Colors.white.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget optimizado para mostrar la imagen del perfil
  Widget _buildProfileImage(Color accentColor) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.9),
            accentColor.withValues(alpha: 0.5),
            accentColor.withValues(alpha: 0.2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.6),
            blurRadius: 20,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: _buildImageContent(),
      ),
    );
  }

  // Contenido de la imagen optimizado
  Widget _buildImageContent() {
    // Si está cargando, mostrar loading
    if (_isLoadingProfile) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // Si tenemos URL de foto, mostrarla
    if (_cachedPhotoUrl != null && _cachedPhotoUrl!.isNotEmpty) {
      return Image.network(
        _cachedPhotoUrl!,
        fit: BoxFit.cover,
        width: 90,
        height: 90,
        errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        },
      );
    }

    // Si no hay foto o no se cargó correctamente, mostrar icono por defecto
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color(0x33BDA206),
            Color(0x1ABDA206),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.type == LoadingScreenType.login ? Icons.waving_hand : Icons.favorite,
          size: 45,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildFloatingParticle(int index, Color accentColor) {
    final random = math.Random(index);
    final startX = random.nextDouble() * 400;
    final startY = random.nextDouble() * 800;
    final size = 2.0 + random.nextDouble() * 6.0;
    final speed = 0.5 + random.nextDouble() * 0.5;
    
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = ((_particleController.value * speed) + (index * 0.1)) % 1.0;
        final x = startX + (math.sin(progress * 2 * math.pi + index) * 60);
        final y = startY - (progress * 120);
        final opacity = math.sin(progress * math.pi);
        
        return Positioned(
          left: x,
          top: y % MediaQuery.of(context).size.height,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: opacity * 0.7),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: opacity * 0.4),
                  blurRadius: size * 2.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}