import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './l10n/app_localizations.dart';
import 'loading_screen.dart';
import 'services/auth_service.dart';

//[-------------PÁGINA DE INICIO DE SESIÓN MULTI-PLATAFORMA--------------]
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
  
  // Variables de estado separadas para cada tipo de login
  bool _loadingEmailLogin = false;
  bool _loadingGoogleLogin = false;
  bool _obscurePassword = true;
  String? _error;

  // Expresiones regulares compiladas para mejor rendimiento
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,}$');

  // Constantes de estilo para mantener consistencia visual
  static const Color _accentColor = Color(0xFFBDA206);
  static const Color _backgroundColor = Colors.black;
  static const Color _cardColor = Color.fromRGBO(15, 19, 21, 0.9);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAuthListener();
     _initializeAuthState();
  }

  //[-------------CONFIGURACIÓN DE LISTENER PARA AUTH--------------]
  void _setupAuthListener() {
  AuthService.setupAuthListener(
    onSignIn: (User user) {
      if (mounted) {
        setState(() {
          _loadingGoogleLogin = false; // Importante: limpiar loading state
          _loadingEmailLogin = false;
          _error = null;
        });
        _checkAndRedirect(user);
      }
    },
    onSignOut: () {
      if (mounted) {
        setState(() {
          _loadingGoogleLogin = false;
          _loadingEmailLogin = false;
          _error = null;
        });
        
        if (kDebugMode) {
          final l10n = AppLocalizations.of(context);
          print(l10n?.userSignedOut ?? 'User signed out');
        }
      }
    },
    onError: (String error) {
      if (mounted) {
        setState(() {
          _loadingGoogleLogin = false;
          _loadingEmailLogin = false;
        });
        final l10n = AppLocalizations.of(context);
        _setError(l10n?.authError(error) ?? 'Authentication error: $error');
      }
    },
  );
}

  //[-------------CONFIGURACIÓN DE ANIMACIONES--------------]
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

  //[-------------LÓGICA DE INICIO DE SESIÓN CON EMAIL/PASSWORD--------------]
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Evitar múltiples llamadas simultáneas
    if (_loadingEmailLogin || _loadingGoogleLogin) return;

    // Feedback háptico
    HapticFeedback.lightImpact();

    setState(() {
      _loadingEmailLogin = true;
      _error = null;
    });

    try {
      final credential = _credentialCtrl.text.trim();
      final password = _passCtrl.text.trim();

      // Verificar si la credencial es un email usando regex compilado
      final bool isEmail = _emailRegex.hasMatch(credential);
      
      if (isEmail) {
        await _attemptEmailLogin(credential, password);
      } else {
        await _attemptUsernameLogin(credential, password);
      }
    } catch (e) {
      _handleLoginError(e);
    } finally {
      if (mounted) {
        setState(() => _loadingEmailLogin = false);
      }
    }
  }

  // Método separado para login con email
  Future<void> _attemptEmailLogin(String email, String password) async {
    final response = await AuthService.signInWithEmailPassword(
      email: email,
      password: password,
    );
    
    if (response.session != null) {
      await _checkAndRedirect(response.user!);
    } else if (mounted) {
      final l10n = AppLocalizations.of(context);
      _setError(l10n?.invalidCredentials ?? 'Invalid credentials');
    }
  }

  // Método separado para login con username
  Future<void> _attemptUsernameLogin(String username, String password) async {
    final userResponse = await AuthService.getUserByUsername(username);
    
    if (userResponse != null && userResponse['email'] != null) {
      final loginEmail = userResponse['email'] as String;
      
      try {
        final response = await AuthService.signInWithEmailPassword(
          email: loginEmail,
          password: password,
        );
        
        if (response.session != null) {
          await _checkAndRedirect(response.user!);
        } else if (mounted) {
          final l10n = AppLocalizations.of(context);
          _setError(l10n?.invalidUsernameCredentials ?? 'Invalid credentials');
        }
      } catch (authError) {
        if (authError is AuthException && authError.message.contains('Invalid login credentials')) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            _setError(l10n?.incorrectPassword(username) ?? 'Incorrect password for user: $username');
          }
          return;
        }
        rethrow;
      }
    } else if (mounted) {
      final l10n = AppLocalizations.of(context);
      _setError(l10n?.userNotFound ?? 'User not found');
    }
  }

  // Manejo centralizado de errores de login
  void _handleLoginError(dynamic e) {
    if (!mounted) return;
    
    String errorMessage;
    final l10n = AppLocalizations.of(context);
    
    if (e is AuthException) {
      errorMessage = _getLocalizedAuthError(e.message);
    } else if (e is PostgrestException) {
      errorMessage = l10n?.databaseConnectionError ?? 'Database connection error';
    } else {
      errorMessage = l10n?.unexpectedLoginError ?? 'Unexpected login error';
      // Log del error para debugging (en desarrollo)
      debugPrint('Error de login: $e');
    }
    
    _setError(errorMessage);
  }

    //[-------------LÓGICA DE INICIO DE SESIÓN CON GOOGLE MEJORADA--------------]
    Future<void> _signInWithGoogle() async {
    // Evitar múltiples llamadas simultáneas
    if (_loadingEmailLogin || _loadingGoogleLogin) return;

    // Feedback háptico
    HapticFeedback.lightImpact();

    setState(() {
      _loadingGoogleLogin = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        // En Web, mostrar mensaje y proceder con OAuth directo
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.signingInWithGoogle ?? 'Signing in with Google...'),
            backgroundColor: _accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final response = await AuthService.signInWithGoogle();
      
      if (response != null && response.session != null) {
        // Login exitoso con respuesta directa (solo en mobile)
        await _checkAndRedirect(response.user!);
      } else if (kIsWeb) {
        // En Web, el OAuth redirect manejará la respuesta
        // El listener se encargará del resto
        if (kDebugMode) {
          print('OAuth redirect iniciado, esperando callback...');
        }
        // No cambiar el loading state aquí, el listener lo manejará
      } else if (mounted) {
        // En Mobile, si no hay respuesta significa que se canceló
        setState(() {
          _loadingGoogleLogin = false;
        });
        final l10n = AppLocalizations.of(context);
        _setError(l10n?.signInCancelled ?? 'Sign in cancelled');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingGoogleLogin = false;
        });
        
        final l10n = AppLocalizations.of(context);
        String errorMessage;
        
        // Manejo específico de errores comunes
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('popup_closed_by_user') || 
            errorString.contains('user_cancelled') ||
            errorString.contains('cancelled')) {
          errorMessage = l10n?.signInCancelled ?? 'Sign in cancelled';
        } else if (errorString.contains('network') || 
                  errorString.contains('connection')) {
          errorMessage = l10n?.connectionError ?? 'Connection error';
        } else if (errorString.contains('invalid_client') ||
                  errorString.contains('unauthorized')) {
          errorMessage = l10n?.configurationError ?? 'Configuration error';
        } else {
          errorMessage = l10n?.unexpectedGoogleError ?? 'Unexpected Google error';
        }
        
        _setError(errorMessage);
        if (kDebugMode) {
          print('Error Google Sign In detallado: $e');
        }
      }
    }
  }


  //[-------------REDIRECCIÓN POST-LOGIN--------------]
  Future<void> _checkAndRedirect(User user) async {
    try {
      final profileExists = await AuthService.getEmployeeProfile(user.id);
      
      if (mounted) {
        if (profileExists != null) {
          final userName = profileExists['username'] as String? ?? 
                          user.email?.split('@')[0] ?? 
                          (AppLocalizations.of(context)?.username ?? 'User');
          
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
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _setError(l10n?.profileVerificationError ?? 'Error verifying profile');
        debugPrint('Error verificando perfil: $e');
      }
    }
  }

  //[-------------MANEJO DE ERRORES--------------]
  void _setError(String error) {
    if (!mounted) return;
    
    setState(() => _error = error);
    
    // Feedback háptico para errores
    HapticFeedback.heavyImpact();
    
    // Auto-limpiar error después de 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _error == error) { // Solo limpiar si es el mismo error
        setState(() => _error = null);
      }
    });
  }

  //Inicializar estado de autenticación
  Future<void> _initializeAuthState() async {
    try {
      // Llamar al nuevo método de inicialización
      await AuthService.initializeAuthState();
      
      // Verificar si ya hay una sesión activa
      final user = AuthService.getCurrentUser();
      if (user != null && mounted) {
        if (kDebugMode) {
          print('Usuario ya autenticado detectado: ${user.email}');
        }
        // Si hay un usuario activo, redirigir automáticamente
        await _checkAndRedirect(user);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando estado de auth: $e');
      }
    }
  }

  // Validaciones mejoradas
  String? _validateEmailOrUsername(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.trim().isEmpty) {
      return l10n?.emailOrUsernameRequired ?? 'Email or username is required';
    }
    
    final trimmedValue = value.trim();
    final bool isValidEmail = _emailRegex.hasMatch(trimmedValue);
    final bool isValidUsername = _usernameRegex.hasMatch(trimmedValue);
    
    if (!isValidEmail && !isValidUsername) {
      return l10n?.invalidEmailOrUsername ?? 'Enter a valid email or username';
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.isEmpty) {
      return l10n?.passwordRequired ?? 'Password is required';
    }
    if (value.length < 6) {
      return l10n?.passwordMinLength ?? 'Password must be at least 6 characters';
    }
    return null;
  }

  // Mapeo mejorado de errores de autenticación
  String _getLocalizedAuthError(String? message) {
    if (message == null) {
      if (!mounted) return 'Authentication error';
      final l10n = AppLocalizations.of(context);
      return l10n?.authErrorGeneric('Error desconocido') ?? 'Authentication error';
    }
    
    if (!mounted) return 'Authentication error: $message';
    final l10n = AppLocalizations.of(context);
    
    // Mapeo directo de errores con fallbacks
    if (message.contains('Invalid login credentials')) {
      return l10n?.authErrorInvalidLogin ?? 'Invalid credentials. Check your email or username and password.';
    }
    if (message.contains('Email not confirmed')) {
      return l10n?.authErrorEmailNotConfirmed ?? 'Email not confirmed. Check your inbox and confirm your account.';
    }
    if (message.contains('Too many requests')) {
      return l10n?.authErrorTooManyRequests ?? 'Too many failed attempts. Wait a few minutes before trying again.';
    }
    if (message.contains('User not found')) {
      return l10n?.authErrorUserNotFound ?? 'User not found. Check your credentials.';
    }
    if (message.contains('Invalid password')) {
      return l10n?.authErrorInvalidPassword ?? 'Incorrect password.';
    }
    if (message.contains('Signup disabled')) {
      return l10n?.authErrorSignupDisabled ?? 'Registration is temporarily disabled.';
    }
    if (message.contains('Email rate limit exceeded')) {
      return l10n?.authErrorEmailRateLimit ?? 'Email limit exceeded. Wait before trying again.';
    }
    
    return l10n?.authErrorGeneric(message) ?? 'Authentication error: $message';
  }

  // Getter para verificar si algún login está en progreso
  bool get _isAnyLoginLoading => _loadingEmailLogin || _loadingGoogleLogin;

  //[-------------CONSTRUCCIÓN DE LA INTERFAZ--------------]
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Ocultar teclado al tocar fuera
        child: Stack(
          children: [
            _buildBackground(),
            _buildLoginForm(),
          ],
        ),
      ),
    );
  }

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

  Widget _buildLoginForm() {
    return SafeArea(
      child: Center(
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
      ),
    );
  }

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
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildGoogleSignInButton(),
          const SizedBox(height: 20),
          _buildRegisterLink(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          'assets/images/logo.png',
          height: 160,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.image_not_supported,
                size: 80,
                color: _accentColor,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      AppLocalizations.of(context)?.appTitle ?? 'LinkTattoo Manager',
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

  Widget _buildErrorMessage() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _error != null ? null : 0,
      child: _error != null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildEmailOrUsernameField() {
    return TextFormField(
      controller: _credentialCtrl,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: _textColor),
      validator: _validateEmailOrUsername,
      enabled: !_isAnyLoginLoading,
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.emailOrUsername ?? 'Email or Username',
        icon: Icons.person_outline,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: _textColor),
      validator: _validatePassword,
      enabled: !_isAnyLoginLoading,
      onFieldSubmitted: (_) => _login(),
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.password ?? 'Password',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _hintColor,
          ),
          onPressed: !_isAnyLoginLoading 
            ? () => setState(() => _obscurePassword = !_obscurePassword)
            : null,
        ),
      ),
    );
  }

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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _hintColor.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: !_isAnyLoginLoading ? () {
          HapticFeedback.lightImpact();
          final l10n = AppLocalizations.of(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n?.passwordRecoveryInDevelopment ?? 'Password recovery feature in development'),
                backgroundColor: _accentColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } : null,
        child: Text(
          AppLocalizations.of(context)?.forgotPassword ?? 'Forgot your password?',
          style: const TextStyle(
            fontSize: 12,
            color: _accentColor,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (!_loadingEmailLogin && !_loadingGoogleLogin) ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: _backgroundColor,
          disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          shadowColor: _accentColor.withValues(alpha: 0.4),
        ),
        child: _loadingEmailLogin
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                  strokeWidth: 2,
                ),
              )
            : Text(
                AppLocalizations.of(context)?.signIn ?? 'Sign In',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _hintColor.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppLocalizations.of(context)?.or ?? 'OR',
            style: TextStyle(
              color: _hintColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _hintColor.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (!_loadingEmailLogin && !_loadingGoogleLogin) ? _signInWithGoogle : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          elevation: 2,
        ),
        icon: _loadingGoogleLogin
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.black87),
                  strokeWidth: 2,
                ),
              )
            : Image.asset(
                'assets/images/google_logo.png',
                height: 20,
                width: 20,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.login,
                    size: 20,
                    color: Colors.black87,
                  );
                },
              ),
        label: Text(
          AppLocalizations.of(context)?.continueWithGoogle ?? 'Continue with Google',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      onPressed: !_isAnyLoginLoading ? () {
        HapticFeedback.lightImpact();
        if (mounted) {
          Navigator.pushNamed(context, '/register');
        }
      } : null,
      child: RichText(
        text: TextSpan(
          text: l10n?.dontHaveAccount ?? "Don't have an account? ",
          style: const TextStyle(color: _hintColor, fontSize: 14),
          children: [
            TextSpan(
              text: l10n?.signUp ?? 'Sign Up',
              style: const TextStyle(
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
    _credentialCtrl.dispose();
    _passCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }
}