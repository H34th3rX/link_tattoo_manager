import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'loading_screen.dart';

//[-------------PÁGINA DE INICIO DE SESIÓN--------------]
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  // Controladores para los campos de texto del formulario
  final _credentialCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y animaciones para efectos de entrada
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Variables de estado para manejar carga, visibilidad de contraseña y errores
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Constantes de estilo para mantener consistencia visual
  static const Color _accentColor = Color(0xFFBDA206);
  static const Color _backgroundColor = Colors.black;
  static const Color _cardColor = Color.fromRGBO(15, 19, 21, 0.9);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;

  @override
  void initState() {
    super.initState();
    // Inicializa las animaciones al cargar la página
    _initializeAnimations();
  }

  //[-------------CONFIGURACIÓN DE ANIMACIONES--------------]
  // Configura las animaciones de deslizamiento y fundido para la entrada del formulario
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  //[-------------LÓGICA DE INICIO DE SESIÓN--------------]
  // Maneja el proceso de autenticación con Supabase, permite login con email o nombre de usuario
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = _credentialCtrl.text.trim();
      final password = _passCtrl.text.trim();

      // Verifica si la credencial es un email
      final bool isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(credential);
      
      if (isEmail) {
        // Login directo con email
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: credential,
          password: password,
        );
        
        if (response.session != null) {
          await _checkAndRedirect(response.user!);
          return;
        }
      } else {
        // Busca el email asociado al nombre de usuario
        final userResponse = await Supabase.instance.client
            .from('employees')
            .select('email, username, id')
            .eq('username', credential)
            .maybeSingle();
        
        if (userResponse != null && userResponse['email'] != null) {
          final loginEmail = userResponse['email'] as String;
          
          // Intenta login con el email encontrado
          try {
            final response = await Supabase.instance.client.auth.signInWithPassword(
              email: loginEmail,
              password: password,
            );
            
            if (response.session != null) {
              await _checkAndRedirect(response.user!);
              return;
            }
          } catch (authError) {
            if (authError is AuthException && authError.message.contains('Invalid login credentials')) {
              _setError('Contraseña incorrecta para el usuario: $credential');
              return;
            }
            rethrow;
          }
        } else {
          _setError('Usuario no encontrado. Verifica que el nombre de usuario sea correcto.');
          return;
        }
      }

      _setError('Credenciales inválidas. Verifica tu email o nombre de usuario y contraseña.');

    } catch (e) {
      if (e is AuthException) {
        _setError(_getLocalizedAuthError(e.message));
      } else if (e is PostgrestException) {
        _setError('Error de conexión con la base de datos. Intenta de nuevo.');
      } else {
        _setError('Error inesperado al iniciar sesión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  //[-------------REDIRECCIÓN POST-LOGIN--------------]
  // Verifica si el usuario tiene un perfil completo y redirige apropiadamente
  Future<void> _checkAndRedirect(User user) async {
    final profileExists = await Supabase.instance.client
        .from('employees')
        .select('id, username')
        .eq('id', user.id)
        .maybeSingle();
    
    if (mounted) {
      if (profileExists != null) {
        final userName = profileExists['username'] as String? ?? user.email!.split('@')[0];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingScreen(userName: userName),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/complete_profile');
      }
    }
  }

  //[-------------MANEJO DE ERRORES--------------]
  // Establece un mensaje de error y lo elimina tras 5 segundos
  void _setError(String error) {
    setState(() => _error = error);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _error = null);
      }
    });
  }

  // Valida el campo de email o nombre de usuario
  String? _validateEmailOrUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email o nombre de usuario es requerido';
    }
    
    final bool isValidEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
    final bool isValidUsername = RegExp(r'^[a-zA-Z0-9_-]{3,}$').hasMatch(value);
    
    if (!isValidEmail && !isValidUsername) {
      return 'Ingresa un email válido o un nombre de usuario (mínimo 3 caracteres, solo letras, números, - y _)';
    }
    
    return null;
  }

  // Traduce errores de autenticación a mensajes amigables
  String _getLocalizedAuthError(String? message) {
    if (message == null) return 'Error de autenticación';
    
    if (message.contains('Invalid login credentials')) {
      return 'Credenciales inválidas. Verifica tu email o nombre de usuario y contraseña.';
    } else if (message.contains('Email not confirmed')) {
      return 'Email no confirmado. Revisa tu bandeja de entrada y confirma tu cuenta.';
    } else if (message.contains('Too many requests')) {
      return 'Demasiados intentos fallidos. Espera unos minutos antes de intentar de nuevo.';
    } else if (message.contains('User not found')) {
      return 'Usuario no encontrado. Verifica tus credenciales.';
    } else if (message.contains('Invalid password')) {
      return 'Contraseña incorrecta.';
    }
    
    return 'Error de autenticación: $message';
  }

  // Valida el campo de contraseña
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  //[-------------CONSTRUCCIÓN DE LA INTERFAZ--------------]
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          _buildBackground(),
          _buildLoginForm(),
        ],
      ),
    );
  }

  // Construye el fondo difuminado con el logo
  Widget _buildBackground() {
    return Positioned.fill(
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
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.3),
          ),
        ),
      ),
    );
  }

  // Construye el formulario de login con animaciones
  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accentColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 8,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Contenido del formulario
  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 32),
          _buildErrorMessage(),
          _buildEmailOrUsernameField(),
          const SizedBox(height: 20),
          _buildPasswordField(),
          const SizedBox(height: 16),
          _buildForgotPasswordLink(),
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 20),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  // Logo de la aplicación
  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.asset(
        'assets/images/logo.png',
        height: 160,
        fit: BoxFit.contain,
      ),
    );
  }

  // Título de la página
  Widget _buildTitle() {
    return Text(
      'LinkTattoo Manager',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _accentColor,
        shadows: [
          Shadow(
            color: _accentColor.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  // Mensaje de error animado
  Widget _buildErrorMessage() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _error != null ? 60 : 0,
      child: _error != null
          ? Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // Campo para email o nombre de usuario
  Widget _buildEmailOrUsernameField() {
    return TextFormField(
      controller: _credentialCtrl,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: _textColor),
      validator: _validateEmailOrUsername,
      decoration: _buildInputDecoration(
        label: 'Email o Nombre de usuario',
        icon: Icons.person_outline,
      ),
    );
  }

  // Campo para la contraseña con opción de visibilidad
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePassword,
      style: const TextStyle(color: _textColor),
      validator: _validatePassword,
      decoration: _buildInputDecoration(
        label: 'Contraseña',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _hintColor,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  // Decoración común para los campos de texto
  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _hintColor),
      filled: true,
      fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
      prefixIcon: Icon(icon, color: _accentColor.withValues(alpha: 0.7)),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // Enlace para recuperar contraseña (en desarrollo)
  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Función de recuperación en desarrollo'),
              backgroundColor: _accentColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            fontSize: 12,
            color: _accentColor,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  // Botón de inicio de sesión
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: _backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: _accentColor.withValues(alpha: 0.4),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // Enlace para registrarse
  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, '/register'),
      child: RichText(
        text: const TextSpan(
          text: '¿No tienes una cuenta? ',
          style: TextStyle(color: _hintColor, fontSize: 14),
          children: [
            TextSpan(
              text: 'Regístrate',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Liberar recursos al destruir el widget
    _credentialCtrl.dispose();
    _passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }
}