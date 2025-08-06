// Importaciones necesarias para animaciones, UI y matemáticas
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------PANTALLA DE CARGA ANIMADA OPTIMIZADA--------------]
class LoadingScreen extends StatefulWidget {
  final String? userName; // Nombre del usuario opcional
  const LoadingScreen({super.key, this.userName});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

// Estado de la pantalla de carga con animaciones
class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  // Controladores de animación para diferentes efectos
  late AnimationController _mainController; // Controla la animación principal
  late AnimationController _pulseController; // Controla el efecto de pulso
  late AnimationController _rotationController; // Controla la rotación de los anillos
  late AnimationController _particleController; // Controla las partículas flotantes
  late AnimationController _textController; // Controla la animación del texto
  
  // Animaciones definidas
  late Animation<double> _progressAnimation; // Animación de la barra de progreso
  late Animation<double> _borderAnimation; // Animación del borde del contenedor
  late Animation<double> _pulseAnimation; // Animación de pulso del contenedor
  late Animation<double> _rotationAnimation; // Animación de rotación de los anillos
  late Animation<double> _scaleAnimation; // Animación de escala para el texto
  late Animation<double> _fadeAnimation; // Animación de opacidad para el texto
  late Animation<Offset> _slideAnimation; // Animación de deslizamiento para el texto

  // Timer para garantizar duración mínima
  Timer? _minimumDurationTimer;
  bool _animationCompleted = false;
  bool _minimumTimeElapsed = false;
  bool _userCheckCompleted = false;

  // Variables para el estado del usuario
  String _statusMessage = 'Iniciando...';
  String _displayName = '';
  String? _redirectRoute;

  @override
  void initState() {
    super.initState();
    
    // Establecer duración mínima garantizada (incluso en release)
    _startMinimumDurationTimer();
    
    // Inicialización del controlador principal (duración extendida para release)
    final duration = kDebugMode 
        ? const Duration(seconds: 4)
        : const Duration(seconds: 6); // Más tiempo en release
    
    _mainController = AnimationController(
      duration: duration,
      vsync: this,
    );
    
    // Controlador para el efecto de pulso, repetitivo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Controlador para la rotación de los anillos, repetitivo
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // Controlador para las partículas flotantes, repetitivo
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    // Controlador para la animación del texto de bienvenida
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Duración extendida
      vsync: this,
    );

    // Configuración de las animaciones con curvas más lentas
    _progressAnimation = CurvedAnimation(
      parent: _mainController, 
      curve: const Interval(0.3, 1.0, curve: Curves.easeInOutCubic), // Inicio más tardío
    );
    
    _borderAnimation = CurvedAnimation(
      parent: _mainController, 
      curve: Curves.easeInOut,
    );
    
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController, 
      curve: Curves.easeInOut,
    );
    
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController, 
      curve: Curves.linear,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _textController, 
      curve: Curves.elasticOut,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _textController, 
      curve: const Interval(0.0, 0.8, curve: Curves.easeIn), // Más lento
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), // Movimiento más pronunciado
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController, 
      curve: Curves.easeOutBack,
    ));

    // Iniciar verificación de usuario y animaciones
    _checkUserStatus();
    
    // Iniciar las animaciones principales con delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mainController.forward();
        _textController.forward();
      }
    });

    // Listener mejorado para la redirección
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationCompleted = true;
        _checkForRedirect();
      }
    });
  }

  // Verificar el estado del usuario y determinar redirección
  Future<void> _checkUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        setState(() {
          _statusMessage = 'Redirigiendo al login...';
          _redirectRoute = '/login';
        });
        _userCheckCompleted = true;
        return;
      }

      setState(() {
        _statusMessage = 'Verificando perfil...';
      });

      // Verificar si el usuario existe en la tabla employees
      final employeeResponse = await Supabase.instance.client
          .from('employees')
          .select('id, username')
          .eq('id', user.id)
          .maybeSingle();

      if (employeeResponse != null) {
        // Es un empleado
        final username = employeeResponse['username'] as String?;
        if (username != null && username.isNotEmpty) {
          // Empleado con perfil completo
          setState(() {
            _displayName = username;
            _statusMessage = 'Preparando dashboard...';
            _redirectRoute = '/dashboard';
          });
        } else {
          // Empleado sin perfil completo
          setState(() {
            _displayName = user.email?.split('@')[0] ?? 'Usuario';
            _statusMessage = 'Completando perfil...';
            _redirectRoute = '/complete_profile';
          });
        }
        _userCheckCompleted = true;
        return;
      }

      // Verificar si el usuario existe en la tabla clients
      if (kDebugMode) {
        print('Checking for client profile for email: ${user.email}');
        print('Attempting to query clients table...');
      }
      final clientResponse = await Supabase.instance.client
          .from('clients')
          .select('id, name')
          .eq('email', user.email!)
          .maybeSingle();

      if (kDebugMode) {
        print('Client profile query result: $clientResponse');
        if (clientResponse == null) {
          print('Client profile NOT found in "clients" table for email: ${user.email}. This might be an RLS issue or missing data.');
        }
      }

      if (clientResponse != null) {
        // Es un cliente con perfil completo
        final clientName = clientResponse['name'] as String?;
        setState(() {
          _displayName = clientName ?? 'Cliente';
          _statusMessage = 'Preparando tu área...';
          _redirectRoute = '/client_dashboard';
        });
        _userCheckCompleted = true;
        return;
      }

      if (kDebugMode) {
        print('Client profile NOT found in "clients" table. Checking metadata...');
      }

      // Usuario autenticado pero sin perfil en ninguna tabla
      // Verificar el tipo de usuario desde metadata
      final userType = user.userMetadata?['user_type'] as String?;
      
      if (userType == 'client') {
        setState(() {
          _displayName = user.email?.split('@')[0] ?? 'Cliente';
          _statusMessage = 'Completando registro...';
          _redirectRoute = '/complete_profile'; // Redirigir a la página unificada
        });
      } else {
        // Por defecto, asumir que es empleado
        setState(() {
          _displayName = user.email?.split('@')[0] ?? 'Usuario';
          _statusMessage = 'Completando perfil...';
          _redirectRoute = '/complete_profile';
        });
      }
      _userCheckCompleted = true;

    } on PostgrestException catch (e) {
      setState(() {
        _statusMessage = 'Error de base de datos';
        _displayName = 'Usuario';
        _redirectRoute = '/login';
      });
      if (kDebugMode) {
        print('PostgrestException en verificación de usuario: ${e.message} (Code: ${e.code})');
      }
      _userCheckCompleted = true;
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al verificar usuario';
        _displayName = 'Usuario';
        _redirectRoute = '/login';
      });
      
      if (kDebugMode) {
        print('Error inesperado en verificación de usuario: $e');
      }
      
      _userCheckCompleted = true;
    }
  }

  // Timer para garantizar duración mínima visible
  void _startMinimumDurationTimer() {
    final minimumDuration = kDebugMode 
        ? const Duration(seconds: 3)
        : const Duration(seconds: 5); // Duración mínima garantizada
    
    _minimumDurationTimer = Timer(minimumDuration, () {
      _minimumTimeElapsed = true;
      _checkForRedirect();
    });
  }

  // Verificar si se puede redirigir (todas las condiciones cumplidas)
  void _checkForRedirect() {
    if (_animationCompleted && _minimumTimeElapsed && _userCheckCompleted && mounted) {
      // Delay adicional para suavizar la transición
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _redirectRoute != null) {
          Navigator.pushReplacementNamed(context, _redirectRoute!);
        }
      });
    }
  }

  @override
  void dispose() {
    // Liberar recursos al destruir el widget
    _minimumDurationTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Constantes de estilo para mantener consistencia visual
    const Color accentColor = Color(0xFFBDA206);
    const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
    const Color textColor = Colors.white;
    const Color hintColor = Colors.white70;

    // Usar el nombre proporcionado o el determinado por la verificación
    final displayName = widget.userName ?? _displayName;

    return Scaffold(
      body: Stack(
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
          
          // Generar 12 partículas flotantes animadas (más partículas para más tiempo)
          ...List.generate(12, (index) => _buildFloatingParticle(index, accentColor)),
          
          // Contenedor central con animaciones
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
                  scale: 1.0 + (_pulseAnimation.value * 0.03), // Pulso más visible
                  child: Container(
                    width: 360, // Contenedor ligeramente más grande
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
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.15),
                          blurRadius: 80,
                          offset: const Offset(0, 40),
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
                        // Icono animado con anillos rotatorios más elaborados
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Anillo externo 1 (rotación en sentido horario)
                            Transform.rotate(
                              angle: _rotationAnimation.value * 2 * math.pi,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.4),
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                            // Anillo intermedio (rotación en sentido antihorario)
                            Transform.rotate(
                              angle: -_rotationAnimation.value * 1.5 * math.pi,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.6),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            // Anillo interno (rotación rápida)
                            Transform.rotate(
                              angle: _rotationAnimation.value * 3 * math.pi,
                              child: Container(
                                width: 85,
                                height: 85,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // Icono central con gradiente mejorado
                            Container(
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
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.waving_hand, 
                                size: 45, 
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 35),
                        
                        // Texto de bienvenida con animaciones mejoradas
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    '¡Bienvenido!',
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
                        
                        // Barra de progreso animada mejorada
                        Stack(
                          children: [
                            // Contenedor base de la barra
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
                            // Barra de progreso con gradiente mejorado
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
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.7),
                                        blurRadius: 12,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Efecto de brillo móvil en la barra
                            if (_progressAnimation.value > 0)
                              Positioned(
                                left: (_progressAnimation.value * 290) - 25,
                                child: Container(
                                  height: 14,
                                  width: 25,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 25),
                        
                        // Porcentaje de progreso animado
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
                        
                        // Mensaje de estado dinámico
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
  }
  
  // Construye una partícula flotante con animación mejorada
  Widget _buildFloatingParticle(int index, Color accentColor) {
    final random = math.Random(index);
    final startX = random.nextDouble() * 400;
    final startY = random.nextDouble() * 800;
    final size = 2.0 + random.nextDouble() * 6.0; // Partículas más variadas
    final speed = 0.5 + random.nextDouble() * 0.5; // Velocidades diferentes
    
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
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}