import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import './l10n/app_localizations.dart';
import 'services/auth_service.dart';

//[-------------PÁGINA PARA ESTABLECER NUEVA CONTRASEÑA SIN ENLACE--------------]
class ResetPasswordPage extends StatefulWidget {
  final String userEmail;
  
  const ResetPasswordPage({
    super.key,
    required this.userEmail,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> 
    with SingleTickerProviderStateMixin {
  
  // Controladores para el formulario
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y animaciones para efectos de entrada
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Variables de estado
  bool _isLoading = false;
  String? _error;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordUpdated = false;
  
  // Constantes de estilo para mantener consistencia visual
  static const Color _accentColor = Color(0xFFBDA206);
  static const Color _backgroundColor = Colors.black;
  static const Color _cardColor = Color.fromRGBO(15, 19, 21, 0.9);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;
  static const Color _successColor = Color(0xFF4CAF50);

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

  //[-------------LÓGICA PARA ACTUALIZAR CONTRASEÑA SIN AUTENTICACIÓN--------------]
  Future<void> _updatePassword() async {
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
      final newPassword = _newPasswordController.text.trim();
      
      if (kDebugMode) {
        print('Actualizando contraseña para: ${widget.userEmail}');
      }
      
      // Actualizar la contraseña directamente usando la función RPC
      await AuthService.updatePasswordDirectly(widget.userEmail, newPassword);
      
      if (mounted) {
        setState(() {
          _passwordUpdated = true;
          _error = null;
        });
        
        // Mostrar mensaje de éxito y redirigir después de unos segundos
        _showSuccessAndRedirect();
      }
      
    } catch (e) {
      _handleUpdateError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  //[-------------MANEJO DE ERRORES--------------]
  void _handleUpdateError(dynamic e) {
    if (!mounted) return;
    
    String errorMessage;
    final l10n = AppLocalizations.of(context);
    
    final errorString = e.toString().toLowerCase();
    
    if (errorString.contains('new password should be different')) {
      errorMessage = l10n?.newPasswordDifferent ?? 
          'La nueva contraseña debe ser diferente a la anterior';
    } else if (errorString.contains('password should be at least')) {
      errorMessage = l10n?.passwordMinLength ?? 
          'La contraseña debe tener al menos 6 caracteres';
    } else if (errorString.contains('usuario registrado con google')) {
      errorMessage = l10n?.googleUserNoPassword ?? 
          'Este usuario está registrado con Google y no necesita restablecer contraseña.';
    } else if (errorString.contains('contacte al administrador')) {
      errorMessage = l10n?.contactAdminError ?? 'No se pudo actualizar la contraseña. Contacte al administrador.';
    } else {
      errorMessage = l10n?.passwordUpdateError ?? 'Error actualizando contraseña';
      if (kDebugMode) {
        debugPrint('Error actualizando contraseña: $e');
      }
    }
    
    _setError(errorMessage);
  }

  //[-------------ÉXITO Y REDIRECCIÓN--------------]
  void _showSuccessAndRedirect() {
    // Esperar 3 segundos y luego redirigir al login
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Navegar de vuelta al login, removiendo todas las páginas anteriores
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
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
  void _navigateBack() {
    HapticFeedback.lightImpact();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  //[-------------VALIDACIONES--------------]
  String? _validateNewPassword(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.isEmpty) {
      return l10n?.passwordRequired ?? 'La contraseña es requerida';
    }
    if (value.length < 6) {
      return l10n?.passwordMinLength ?? 'La contraseña debe tener al menos 6 caracteres';
    }
    if (value.length > 72) {
      return l10n?.passwordMaxLength ?? 'La contraseña debe tener menos de 72 caracteres';
    }
    
    // Verificar que tenga al menos una letra y un número
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return l10n?.passwordRequirements ?? 
          'La contraseña debe contener al menos una letra y un número';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!mounted) return null;
    final l10n = AppLocalizations.of(context);
    
    if (value == null || value.isEmpty) {
      return l10n?.confirmPasswordRequired ?? 'Confirma tu contraseña';
    }
    if (value != _newPasswordController.text) {
      return l10n?.passwordsDoNotMatch ?? 'Las contraseñas no coinciden';
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
            _buildResetForm(),
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

  Widget _buildResetForm() {
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
                      color: _passwordUpdated ? _successColor : _accentColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_passwordUpdated ? _successColor : _accentColor)
                            .withValues(alpha: 0.3),
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
    if (_passwordUpdated) {
      return _buildSuccessContent();
    }
    
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
          _buildNewPasswordField(),
          const SizedBox(height: 20),
          _buildConfirmPasswordField(),
          const SizedBox(height: 24),
          _buildUpdateButton(),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          color: _successColor,
          size: 80,
        ),
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)?.passwordUpdatedTitle ?? '¡Contraseña Actualizada!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _successColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)?.passwordUpdatedMessage ?? 
              'Tu contraseña ha sido actualizada exitosamente. Serás redirigido a la página de inicio de sesión.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          valueColor: AlwaysStoppedAnimation(_successColor),
          backgroundColor: _successColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: !_isLoading && !_passwordUpdated ? _navigateBack : null,
        icon: const Icon(
          Icons.arrow_back_ios,
          color: _accentColor,
        ),
        tooltip: AppLocalizations.of(context)?.back ?? 'Volver',
      ),
    );
  }

  Widget _buildLogo() {
    return Hero(
      tag: 'app_logo_reset',
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
                Icons.lock_outline,
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
      AppLocalizations.of(context)?.setNewPassword ?? 'Establecer Nueva Contraseña',
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
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)?.setNewPasswordSubtitle ?? 
              'Ingresa tu nueva contraseña a continuación',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _hintColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            widget.userEmail,
            style: const TextStyle(
              color: _accentColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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

  Widget _buildNewPasswordField() {
    return TextFormField(
      controller: _newPasswordController,
      obscureText: _obscureNewPassword,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: _textColor),
      validator: _validateNewPassword,
      enabled: !_isLoading,
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.newPassword ?? 'Nueva Contraseña',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _hintColor,
          ),
          onPressed: !_isLoading 
            ? () => setState(() => _obscureNewPassword = !_obscureNewPassword)
            : null,
        ),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: _textColor),
      validator: _validateConfirmPassword,
      enabled: !_isLoading,
      onFieldSubmitted: (_) => _updatePassword(),
      decoration: _buildInputDecoration(
        label: AppLocalizations.of(context)?.confirmPassword ?? 'Confirmar Contraseña',
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: _hintColor,
          ),
          onPressed: !_isLoading 
            ? () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
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

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: !_isLoading ? _updatePassword : null,
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
                AppLocalizations.of(context)?.updatePassword ?? 'Actualizar Contraseña',
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
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
