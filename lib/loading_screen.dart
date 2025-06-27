import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final String userName;
  const LoadingScreen({super.key, required this.userName});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _particleController;
  late AnimationController _textController;
  
  late Animation<double> _progressAnimation;
  late Animation<double> _borderAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controlador principal
    _mainController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    // Controlador de pulso
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Controlador de rotación
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // Controlador de partículas
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    // Controlador de texto
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animaciones
    _progressAnimation = CurvedAnimation(
      parent: _mainController, 
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic)
    );
    
    _borderAnimation = CurvedAnimation(
      parent: _mainController, 
      curve: Curves.easeInOut
    );
    
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController, 
      curve: Curves.easeInOut
    );
    
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController, 
      curve: Curves.linear
    );
    

    
    _scaleAnimation = CurvedAnimation(
      parent: _textController, 
      curve: Curves.elasticOut
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _textController, 
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn)
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController, 
      curve: Curves.easeOutBack
    ));

    // Iniciar animaciones
    _mainController.forward();
    _textController.forward();

    // Redirigir al dashboard cuando la animación llegue al 100%
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFFBDA206);
    const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
    const Color textColor = Colors.white;
    const Color hintColor = Colors.white70;

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
          
          // Partículas flotantes
          ...List.generate(8, (index) => _buildFloatingParticle(index, accentColor)),
          
          // Cuadro centralizado con información
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
                  scale: 1.0 + (_pulseAnimation.value * 0.02),
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3 + (_pulseAnimation.value * 0.2)),
                          blurRadius: 30 + (_pulseAnimation.value * 10),
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 60,
                          offset: const Offset(0, 30),
                        ),
                      ],
                      border: Border.all(
                        color: accentColor.withValues(alpha: _borderAnimation.value * 0.8),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icono animado con anillos
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Anillos externos rotatorios
                            Transform.rotate(
                              angle: _rotationAnimation.value * 2 * math.pi,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -_rotationAnimation.value * 1.5 * math.pi,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            // Icono central
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accentColor.withValues(alpha: 0.8),
                                    accentColor.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.waving_hand, 
                                size: 40, 
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Texto de bienvenida animado
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Text(
                                '¡Bienvenido,\n${widget.userName}!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  shadows: [
                                    Shadow(
                                      color: accentColor.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Barra de progreso futurista
                        Stack(
                          children: [
                            // Contenedor base
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: hintColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            // Barra de progreso animada
                            SizedBox(
                              height: 12,
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _progressAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withValues(alpha: 0.8),
                                        accentColor,
                                        Colors.white.withValues(alpha: 0.9),
                                      ],
                                      stops: const [0.0, 0.7, 1.0],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Efecto de brillo móvil
                            if (_progressAnimation.value > 0)
                              Positioned(
                                left: (_progressAnimation.value * 280) - 20,
                                child: Container(
                                  height: 12,
                                  width: 20,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(alpha: 0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Porcentaje animado
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Text(
                              '${(_progressAnimation.value * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                                shadows: [
                                  Shadow(
                                    color: accentColor.withValues(alpha: 0.5),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            );
                          },
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

  Widget _buildFloatingParticle(int index, Color accentColor) {
    final random = math.Random(index);
    final startX = random.nextDouble() * 400;
    final startY = random.nextDouble() * 800;
    final size = 3.0 + random.nextDouble() * 4.0;
    
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = (_particleController.value + (index * 0.1)) % 1.0;
        final x = startX + (math.sin(progress * 2 * math.pi) * 50);
        final y = startY - (progress * 100);
        final opacity = math.sin(progress * math.pi);
        
        return Positioned(
          left: x,
          top: y % MediaQuery.of(context).size.height,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: opacity * 0.6),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: opacity * 0.3),
                  blurRadius: size * 2,
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