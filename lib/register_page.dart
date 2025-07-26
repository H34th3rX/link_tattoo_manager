import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './l10n/app_localizations.dart';

//[-------------PÁGINA DE REGISTRO--------------]
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  // Constantes para estilos
  static const Color _accentColor = Color(0xFFBDA206);
  static const Color _backgroundColor = Colors.black;
  static const Color _cardColor = Color.fromRGBO(15, 19, 21, 0.9);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;

  // Controladores para los campos del formulario
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y variables para animaciones y estado
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Inicializa las animaciones al cargar la página
    _initializeAnimations();
  }

  // Configura las animaciones de deslizamiento y opacidad
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

  // Maneja el proceso de registro con Supabase
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (response.user != null && mounted) {
        final l10n = AppLocalizations.of(context);
        _showSuccessDialog(l10n?.accountCreated ?? 'Account created. A verification email has been sent.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      } else if (mounted) {
        final l10n = AppLocalizations.of(context);
        _setError(l10n?.accountCreationFailed ?? 'Could not create account. Please try again.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        _setError(_getLocalizedAuthError(e.message));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _setError(l10n?.unexpectedError ?? 'Unexpected error. Please check your internet connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Muestra mensaje de error con duración
  void _setError(String error) {
    setState(() => _error = error);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _error = null);
      }
    });
  }

  // Muestra un diálogo de éxito
  void _showSuccessDialog(String message) {
    if (!mounted) return;

    // Obtener localización para el botón "OK" antes del diálogo
    final l10n = AppLocalizations.of(context);
    final okText = l10n?.ok ?? 'OK';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textColor, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(okText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Traduce errores de autenticación a mensajes legibles
  String _getLocalizedAuthError(String? message) {
    if (message == null) {
      if (!mounted) return 'Authentication error';
      final l10n = AppLocalizations.of(context);
      return l10n?.authErrorGeneric('Unknown error') ?? 'Authentication error';
    }
    
    if (!mounted) return 'Authentication error: $message';
    final l10n = AppLocalizations.of(context);

    if (message.contains('User already registered')) {
      return l10n?.userAlreadyRegistered ?? 'This email is already registered. Please try logging in.';
    } else if (message.contains('Password should be at least')) {
      return l10n?.passwordMinLength ?? 'The password must be at least 6 characters.';
    } else if (message.contains('Invalid email')) {
      return l10n?.invalidEmailFormat ?? 'The email format is invalid.';
    } else if (message.contains('signup is disabled')) {
      return l10n?.authErrorSignupDisabled ?? 'Registration is temporarily disabled.';
    }
    
    return l10n?.authErrorGeneric(message) ?? message;
  }

  // Validaciones para los campos del formulario
  String? _validateEmail(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.isEmpty) {
      return l10n?.emailRequired ?? 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return l10n?.invalidEmail ?? 'Enter a valid email';
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
    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
      return l10n?.passwordComplexity ?? 'Password must contain at least one letter and one number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.isEmpty) {
      return l10n?.confirmPasswordRequired ?? 'Confirm your password';
    }
    if (value != _passwordCtrl.text) {
      return l10n?.passwordsDontMatch ?? 'Passwords do not match';
    }
    return null;
  }

  // Construye la interfaz principal
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          _buildBackground(),
          _buildRegisterForm(),
        ],
      ),
    );
  }

  // Construye el fondo difuminado
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

  // Construye el formulario de registro
  Widget _buildRegisterForm() {
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 16),
                      _buildTitle(),
                      const SizedBox(height: 32),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
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
                        ),
                      ],
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildPasswordField(),
                      const SizedBox(height: 20),
                      _buildConfirmPasswordField(),
                      const SizedBox(height: 24),
                      _buildRegisterButton(),
                      const SizedBox(height: 20),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Construye el logo de la aplicación
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

  // Construye el título del formulario
  Widget _buildTitle() {
    return Text(
      AppLocalizations.of(context)?.registerTitle ?? 'Register',
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

  // Construye el campo de email
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: _textColor),
      validator: _validateEmail,
      enabled: !_loading,
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.emailLabel ?? 'Email address',
        icon: Icons.email_outlined,
      ),
    );
  }

  // Construye el campo de contraseña
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      style: const TextStyle(color: _textColor),
      validator: _validatePassword,
      enabled: !_loading,
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.passwordLabel ?? 'Password',
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

  // Construye el campo de confirmación de contraseña
  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordCtrl,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(color: _textColor),
      validator: _validateConfirmPassword,
      enabled: !_loading,
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.confirmPasswordLabel ?? 'Confirm password',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _hintColor,
          ),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
    );
  }

  // Construye la decoración para los campos de entrada
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

  // Construye el botón de registro
  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _register,
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
            : Text(
                AppLocalizations.of(context)?.signUp ?? 'Sign Up',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // Construye el enlace para iniciar sesión
  Widget _buildLoginLink() {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      onPressed: _loading
          ? null
          : () => Navigator.pushReplacementNamed(context, '/login'),
      child: RichText(
        text: TextSpan(
          text: l10n?.alreadyHaveAccount ?? 'Already have an account? ',
          style: const TextStyle(color: _hintColor, fontSize: 14),
          children: [
            TextSpan(
              text: l10n?.signIn ?? 'Sign In',
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
    // Libera recursos
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }
}