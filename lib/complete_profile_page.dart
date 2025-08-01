// Importaciones necesarias para la UI, Supabase y animaciones
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'loading_screen.dart';

//[-------------PÁGINA PARA COMPLETAR EL PERFIL DEL USUARIO--------------]
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage>
    with SingleTickerProviderStateMixin {
  // Controladores para los campos de texto del formulario
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y animaciones para efectos de entrada y salida
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Estados para manejar la carga, errores y la selección de especialidad
  bool _loading = false;
  String? _error;
  String? _selectedSpecialty;
  bool _isCustomSpecialty = false;
  bool _isShaking = false;

  // Constantes de estilo para mantener consistencia visual
  static const Color _accentColor = Color(0xFFBDA206);
  static const Color _backgroundColor = Colors.black;
  static const Color _cardColor = Color.fromRGBO(15, 19, 21, 0.9);
  static const Color _textColor = Colors.white;
  static const Color _hintColor = Colors.white70;

  // Lista de especialidades predefinidas para el dropdown
  final List<String> _specialties = ['Tradicional', 'Realismo', 'Acuarela', 'Minimalista', 'Neotradicional', 'Otro'];

  @override
  void initState() {
    super.initState();
    // Inicialización del controlador de animación para la entrada de la UI
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    // Animación de deslizamiento desde abajo hacia arriba
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    // Animación de opacidad para un efecto de fundido
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    // Ejecuta la animación después de que el frame inicial se haya renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
    // Listener para verificar la disponibilidad del nombre de usuario en tiempo real
    _usernameCtrl.addListener(_checkUsernameAvailability);
  }

  // Verifica si el nombre de usuario ya está en uso en Supabase
  Future<void> _checkUsernameAvailability() async {
    if (_usernameCtrl.text.isNotEmpty && mounted) {
      final response = await Supabase.instance.client
          .from('employees')
          .select('username')
          .eq('username', _usernameCtrl.text.trim())
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _error = 'Este nombre de usuario ya está en uso. Elige otro.';
          _isShaking = true;
          _triggerShake();
        });
      } else if (_error?.contains('ya está en uso') == true && mounted) {
        setState(() {
          _error = null;
          _isShaking = false;
        });
      }
    }
  }

  // Activa una animación de "sacudida" para el contenedor en caso de error
  void _triggerShake() {
    if (_isShaking) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _error != null) {
          setState(() => _isShaking = false);
        }
      });
    }
  }

  // Guarda el perfil del usuario en Supabase
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) _setError('Usuario no autenticado');
        return;
      }

      // Verifica si el perfil ya existe antes de intentar insertar
      final existingProfile = await Supabase.instance.client
          .from('employees')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        if (mounted) _setError('El perfil ya existe. Contacta al soporte si necesitas modificarlo.');
        return;
      }

      // Actualiza los atributos del usuario en Supabase Auth
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
        'username': _usernameCtrl.text.trim(),
      }));

      // Inserta los datos del empleado en la tabla 'employees'
      await Supabase.instance.client.from('employees').insert({
        'id': user.id,
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': user.email,
        'specialty': _isCustomSpecialty && _specialtyCtrl.text.isNotEmpty
            ? _specialtyCtrl.text.trim()
            : _selectedSpecialty,
        'start_date': DateTime.now().toIso8601String().split('T')[0],
        'is_active': true,
        'notes': null,
      });

      if (mounted) {
        // SOLUCIÓN: Navegar directamente sin diálogo intermedio
        _navigateToLoadingScreen();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        if (e.code == '42501') {
          _setError('Error de permisos al guardar el perfil. Contacta al soporte.');
        } else {
          _setError('Error al guardar el perfil: ${e.message}. Verifica los datos o contacta al soporte.');
        }
      }
    } catch (e) {
      if (mounted) {
        _setError('Error inesperado al guardar el perfil: $e. Contacta al soporte.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // NUEVA FUNCIÓN: Navegar directamente a la pantalla de carga
  void _navigateToLoadingScreen() {
    // Usar WidgetsBinding para asegurar que la navegación ocurra en el próximo frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingScreen(userName: _usernameCtrl.text.trim()),
          ),
        );
      }
    });
  }

  // Establece un mensaje de error y lo elimina tras 5 segundos
  void _setError(String error) {
    setState(() => _error = error);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _error = null);
      }
    });
  }

  // FUNCIÓN ELIMINADA: _showSuccessDialog ya no se usa

  @override
  Widget build(BuildContext context) {
    // Construye la interfaz principal con fondo difuminado y formulario
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Fondo con imagen difuminada
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
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: const Color.fromRGBO(0, 0, 0, 0.3),
                ),
              ),
            ),
          ),
          // Contenido principal con scroll
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      transform: _isShaking
                          ? (Matrix4.translationValues(10, 0, 0)..rotateZ(0.02))
                          : Matrix4.identity(),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _accentColor, width: 2),
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
                              // Logo en la parte superior
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 160,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Título del formulario
                              Text(
                                'Completar Perfil',
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
                              ),
                              const SizedBox(height: 32),
                              // Mensaje de error si existe
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.redAccent),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Campo para el nombre de usuario
                              TextFormField(
                                controller: _usernameCtrl,
                                style: const TextStyle(color: _textColor),
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Requerido'
                                    : (_error?.contains('ya está en uso') == true ? 'Nombre en uso' : null),
                                decoration: InputDecoration(
                                  labelText: 'Nombre de usuario',
                                  labelStyle: const TextStyle(color: _hintColor),
                                  filled: true,
                                  fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                                  prefixIcon: Icon(Icons.person_outline, color: _accentColor.withValues(alpha: 0.7)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Campo para el teléfono
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: _textColor),
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Requerido'
                                    : (value.length < 8 ? 'El teléfono debe tener al menos 8 dígitos' : null),
                                decoration: InputDecoration(
                                  labelText: 'Teléfono',
                                  labelStyle: const TextStyle(color: _hintColor),
                                  filled: true,
                                  fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                                  prefixIcon: Icon(Icons.phone, color: _accentColor.withValues(alpha: 0.7)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Dropdown para seleccionar especialidad
                              DropdownButtonFormField<String>(
                                value: _selectedSpecialty,
                                hint: const Text('Selecciona una especialidad', style: TextStyle(color: _hintColor)),
                                items: _specialties.map((String specialty) {
                                  return DropdownMenuItem<String>(
                                    value: specialty,
                                    child: Text(specialty, style: const TextStyle(color: _textColor)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      _selectedSpecialty = value;
                                      _isCustomSpecialty = value == 'Otro';
                                      if (!_isCustomSpecialty) _specialtyCtrl.clear();
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: 'Especialidad',
                                  labelStyle: const TextStyle(color: _hintColor),
                                  filled: true,
                                  fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                                  prefixIcon: Icon(Icons.brush, color: _accentColor.withValues(alpha: 0.7)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.redAccent),
                                  ),
                                ),
                                dropdownColor: _cardColor,
                                style: const TextStyle(color: _textColor),
                                validator: (value) => value == null ? 'Selecciona una especialidad' : null,
                              ),
                              // Campo para especialidad personalizada si se selecciona 'Otro'
                              if (_isCustomSpecialty) ...[
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _specialtyCtrl,
                                  style: const TextStyle(color: _textColor),
                                  validator: (value) => _isCustomSpecialty && (value == null || value.isEmpty)
                                      ? 'Ingresa una especialidad personalizada'
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: 'Especialidad personalizada',
                                    labelStyle: const TextStyle(color: _hintColor),
                                    filled: true,
                                    fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                                    prefixIcon: Icon(Icons.edit, color: _accentColor.withValues(alpha: 0.7)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              // Botón para guardar el perfil
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accentColor,
                                    foregroundColor: _backgroundColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                          'Guardar Perfil',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Limpieza de recursos al destruir el widget
    _usernameCtrl.removeListener(_checkUsernameAvailability);
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }
}