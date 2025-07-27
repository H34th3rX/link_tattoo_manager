import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import './l10n/app_localizations.dart';
import 'services/auth_service.dart';
import 'reset_password_page.dart';

//[-------------PÁGINA DE RECUPERACIÓN DE CONTRASEÑA SIN EMAIL--------------]
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> 
    with SingleTickerProviderStateMixin {
  
  // Controladores para el formulario
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y animaciones para efectos de entrada
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Variables de estado
  bool _isLoading = false;
  String? _error;
  
  // Expresiones regulares compiladas para mejor rendimiento
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  
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

  //[-------------LÓGICA DE VERIFICACIÓN Y NAVEGACIÓN DIRECTA--------------]
  Future<void> _verifyAndNavigate() async {
    if (!_formKey.currentState!.validate()) return;

    // Evitar múltiples llamadas simultáneas
    if (_isLoading) return;

    // Feedback háptico
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      
      if (kDebugMode) {
        print('Verificando usuario: $email');
      }
      
      // Verificar si el usuario puede resetear contraseña usando la nueva RPC
      final userStatus = await AuthService.checkUserCanResetPassword(email);
      
      if (kDebugMode) {
        print('Estado del usuario: $userStatus');
      }
      
      if (!userStatus['exists']) {
        throw Exception('user_not_found');
      }
      
      if (userStatus['isGoogleUser']) {
        throw Exception('google_user_no_password');
      }
      
      if (!userStatus['canReset']) {
        // Este caso debería ser raro si isGoogleUser ya se manejó,
        // pero es para robustez si hay otras condiciones de "no puede resetear".
        throw Exception('cannot_reset_password');
      }

      // Si llegamos aquí, el usuario existe y puede restablecer su contraseña
      if (mounted) {
        // Navegar directamente a la página de reset password, pasando el email
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(userEmail: email),
          ),
        );
      }
      
    } catch (e) {
      _handleVerificationError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  //[-------------MANEJO DE ERRORES--------------]
  void _handleVerificationError(dynamic e) {
    if (!mounted) return;
    
    String errorMessage;
    final l10n = AppLocalizations.of(context);
    
    final errorString = e.toString().toLowerCase();
    
    if (errorString.contains('user_not_found')) {
      errorMessage = l10n?.userNotFoundOrGoogle ?? 
          'Usuario no encontrado. Verifica que el correo sea correcto.';
    } else if (errorString.contains('google_user_no_password')) {
      errorMessage = l10n?.googleUserNoPassword ?? 
          'Este usuario está registrado con Google y no necesita restablecer contraseña.';
    } else if (errorString.contains('cannot_reset_password')) {
      errorMessage = l10n?.cannotResetPassword ?? 'No se puede restablecer la contraseña para este usuario.';
    } else {
      errorMessage = l10n?.recoveryError ?? 'Error verificando usuario. Intenta de nuevo.';
      // Log del error para debugging (en desarrollo)
      if (kDebugMode) {
        debugPrint('Error de verificación: $e');
      }
    }
    
    _setError(errorMessage);
  }

  //[-------------MANEJO DE ERRORES--------------]
  void _setError(String error) {
    if (!mounted) return;
    
    setState(() => _error = error);
    
    // Feedback háptico para errores
    HapticFeedback.heavyImpact();
    
    // Auto-limpiar error después de 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _error == error) {
        setState(() => _error = null);
      }
    });
  }

  //[-------------NAVEGACIÓN DE REGRESO--------------]
  void _navigateBackToLogin() {
    HapticFeedback.lightImpact();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  //[-------------VALIDACIONES--------------]
  String? _validateEmail(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.trim().isEmpty) {
      return l10n?.emailRequired ?? 'El correo electrónico es requerido';
    }
    
    final trimmedValue = value.trim();
    if (!_emailRegex.hasMatch(trimmedValue)) {
      return l10n?.emailNotValid ?? 'El formato del correo electrónico no es válido';
    }
    
    return null;
  }

  //[-------------CONSTRUCCIÓN DE LA INTERFAZ--------------]
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            _buildBackground(),
            _buildRecoveryForm(),
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

  Widget _buildRecoveryForm() {
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
          _buildBackButton(),
          const SizedBox(height: 16),
          _buildLogo(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 8),
          _buildSubtitle(),
          const SizedBox(height: 32),
          _buildErrorMessage(),
          _buildEmailField(),
          const SizedBox(height: 24),
          _buildVerifyButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: !_isLoading ? _navigateBackToLogin : null,
        icon: const Icon(
          Icons.arrow_back_ios,
          color: _accentColor,
        ),
        tooltip: AppLocalizations.of(context)?.backToLogin ?? 'Volver al Login',
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo_recovery',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.asset(
          'assets/images/logo.png',
          height: 120,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.lock_reset,
                size: 60,
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
      AppLocalizations.of(context)?.passwordRecoveryTitle ?? 'Restablecer Contraseña',
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

  Widget _buildSubtitle() {
    return Text(
      AppLocalizations.of(context)?.passwordRecoverySubtitle ?? 
          'Ingresa tu correo electrónico para verificar tu cuenta',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _hintColor,
        fontSize: 14,
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

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: _textColor),
      validator: _validateEmail,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _verifyAndNavigate(),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)?.enterEmail ?? 'Ingresa tu correo electrónico',
        labelStyle: const TextStyle(color: _hintColor),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: _accentColor.withValues(alpha: 0.7),
        ),
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
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: !_isLoading ? _verifyAndNavigate : null,
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
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.black),
                  strokeWidth: 2,
                ),
              )
            : Text(
                AppLocalizations.of(context)?.verifyAndContinue ?? 'Verificar y Continuar',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
