import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shake/shake.dart';
import 'dart:ui' as ui;

//[-------------PÁGINA PARA COMPLETAR EL PERFIL DEL USUARIO (UNIFICADA)--------------]
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController(); // Usado para especialidad de empleado o notas de cliente

  // Variables de estado
  bool _loading = false;
  String? _error;
  String? _selectedSpecialty; // Para empleados
  bool _isCustomSpecialty = false; // Para empleados
  bool _isShaking = false; // Para animación de error
  String? _userType; // Ahora puede ser null al inicio, se seleccionará aquí
  bool _userTypeSelected = false; // Controla si el tipo de usuario ya fue seleccionado
  String? _selectedEmployeeId; // Para clientes
  List<Map<String, dynamic>> _employees = []; // Lista de empleados para clientes
  String _selectedContactMethod = 'Email'; // Para clientes

  ShakeDetector? _shakeDetector;

  // Lista de especialidades predefinidas para el dropdown (para empleados)
  final List<String> _specialties = [
    'Tradicional',
    'Realismo',
    'Acuarela',
    'Blackwork',
    'Neotradicional',
    'Japonés',
    'Geométrico',
    'Otro',
  ];

  // Constantes de estilo para mantener consistencia visual
  final Color _accentColor = const Color(0xFFBDA206);
  final Color _backgroundColor = Colors.black;
  final Color _cardColor = const Color.fromRGBO(15, 19, 21, 0.9);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.white70;

  @override
  void initState() {
    super.initState();
    _checkInitialUserType(); // Verifica si el tipo de usuario ya está en metadata
    _initShakeDetector();
  }

  // Inicializa ShakeDetector para la animación de error
  void _initShakeDetector() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (ShakeEvent event) {
        if (mounted) {
          setState(() {
            _isShaking = true;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _isShaking = false;
              });
            }
          });
        }
      },
      shakeThresholdGravity: 5,
    );
  }

  // Verifica si el tipo de usuario ya está en la metadata al cargar la página
  Future<void> _checkInitialUserType() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userTypeFromMetadata = user.userMetadata?['user_type'] as String?;
      if (userTypeFromMetadata != null && userTypeFromMetadata.isNotEmpty) {
        setState(() {
          _userType = userTypeFromMetadata;
          _userTypeSelected = true;
        });
        if (_userType == 'client') {
          await _loadEmployees();
        }
      } else {
        // Si no hay user_type en metadata, se mostrará la selección
        setState(() {
          _userTypeSelected = false;
        });
      }
    } else {
      // Si no hay usuario autenticado, redirigir al login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // Carga la lista de empleados desde Supabase (solo para usuarios tipo cliente)
  Future<void> _loadEmployees() async {
    try {
      final response = await Supabase.instance.client
          .from('employees')
          .select('id, username')
          .eq('is_active', true)
          .order('username');

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      if (mounted) {
        _setError('Error al cargar tatuadores: $e');
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    _shakeDetector?.stopListening();
    super.dispose();
  }

  // Establece un mensaje de error y lo limpia después de 5 segundos
  void _setError(String message) {
    setState(() {
      _error = message;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _error = null);
      }
    });
  }

  // Guarda el perfil del usuario (empleado o cliente) en Supabase
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación específica para clientes: deben seleccionar un empleado
    if (_userType == 'client' && _selectedEmployeeId == null) {
      _setError('Debe seleccionar un tatuador'); // Mensaje actualizado
      return;
    }

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

      // Si el user_type no ha sido guardado en metadata, lo hacemos ahora
      if (user.userMetadata?['user_type'] == null || user.userMetadata?['user_type'] == '') {
        await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
          'user_type': _userType,
        }));
      }

      if (_userType == 'employee') {
        // Lógica para guardar perfil de empleado
        final existingProfile = await Supabase.instance.client
            .from('employees')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (existingProfile != null) {
          if (mounted) _setError('El perfil ya existe. Contacta al soporte si necesitas modificarlo.');
          return;
        }

        // Actualiza los atributos del usuario en Supabase Auth (ej. username)
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
      } else if (_userType == 'client') {
        // Lógica para guardar perfil de cliente
        // Primero, verifica si el perfil de cliente ya existe para este email
        final existingClientProfile = await Supabase.instance.client
            .from('clients')
            .select('id')
            .eq('email', user.email!)
            .maybeSingle();

        if (existingClientProfile != null) {
          if (mounted) _setError('Tu perfil de cliente ya existe. No se puede crear de nuevo.');
          return; // Evita la reinserción si el perfil ya existe
        }

        // Si el perfil no existe, procede con la inserción
        await Supabase.instance.client.from('clients').insert({
          'employee_id': _selectedEmployeeId,
          'name': _usernameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
          'email': user.email,
          'notes': _specialtyCtrl.text.trim().isNotEmpty ? _specialtyCtrl.text.trim() : null, // Usamos specialtyCtrl para notas
          'preferred_contact_method': _selectedContactMethod,
        });
      }

      if (mounted) {
        _navigateToLoadingScreen(); // Redirige a la pantalla de carga para determinar el dashboard
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

  // Navega a la pantalla de carga, que luego redirigirá al dashboard correcto
  void _navigateToLoadingScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/loading');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Fondo con imagen difuminada
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/logo.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    const Color.fromRGBO(0, 0, 0, 0.7),
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
                    child: _userTypeSelected ? _buildProfileForm() : _buildUserTypeSelection(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para la selección del tipo de usuario
  Widget _buildUserTypeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/images/logo.png',
            height: 160,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Selecciona tu tipo de usuario',
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
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _setUserType('employee'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              shadowColor: _accentColor.withValues(alpha: 0.4),
            ),
            child: const Text(
              'Soy un Empleado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _setUserType('client'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              shadowColor: _accentColor.withValues(alpha: 0.4),
            ),
            child: const Text(
              'Soy un Cliente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // Función para establecer el tipo de usuario y actualizar metadata
  Future<void> _setUserType(String type) async {
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

      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
        'user_type': type,
      }));

      setState(() {
        _userType = type;
        _userTypeSelected = true;
      });

      if (type == 'client') {
        await _loadEmployees();
      }
    } on AuthException catch (e) {
      if (mounted) _setError('Error al guardar el tipo de usuario: ${e.message}');
    } catch (e) {
      if (mounted) _setError('Error inesperado al guardar el tipo de usuario: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Widget para el formulario de perfil (empleado o cliente)
  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/images/logo.png',
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userType == 'client' ? 'Completar Perfil de Cliente' : 'Completar Perfil de Empleado',
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
          TextFormField(
            controller: _usernameCtrl,
            style: TextStyle(color: _textColor),
            validator: (value) => value == null || value.isEmpty
                ? 'Requerido'
                : null,
            decoration: InputDecoration(
              labelText: _userType == 'client' ? 'Nombre completo' : 'Nombre de usuario',
              labelStyle: TextStyle(color: _hintColor),
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
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: _textColor),
            validator: (value) {
              if (_userType == 'employee' && (value == null || value.isEmpty)) {
                return 'Requerido';
              }
              if (value != null && value.isNotEmpty && value.length < 8) {
                return 'El teléfono debe tener al menos 8 dígitos';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Teléfono',
              labelStyle: TextStyle(color: _hintColor),
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

          if (_userType == 'employee') ...[
            DropdownButtonFormField<String>(
              value: _selectedSpecialty,
              hint: Text('Selecciona una especialidad', style: TextStyle(color: _hintColor)),
              items: _specialties.map((String specialty) {
                return DropdownMenuItem<String>(
                  value: specialty,
                  child: Text(specialty, style: TextStyle(color: _textColor)),
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
                labelStyle: TextStyle(color: _hintColor),
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
              style: TextStyle(color: _textColor),
              validator: (value) => value == null ? 'Selecciona una especialidad' : null,
            ),
            if (_isCustomSpecialty) ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _specialtyCtrl,
                style: TextStyle(color: _textColor),
                validator: (value) => _isCustomSpecialty && (value == null || value.isEmpty)
                    ? 'Ingresa una especialidad personalizada'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Especialidad personalizada',
                  labelStyle: TextStyle(color: _hintColor),
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
          ],

          if (_userType == 'client') ...[
            DropdownButtonFormField<String>(
              value: _selectedContactMethod,
              decoration: InputDecoration(
                labelText: 'Método de contacto preferido',
                labelStyle: TextStyle(color: _hintColor),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                prefixIcon: Icon(Icons.contact_phone_outlined, color: _accentColor.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                ),
              ),
              dropdownColor: _cardColor,
              style: TextStyle(color: _textColor),
              items: ['Email', 'Phone', 'WhatsApp'].map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedContactMethod = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedEmployeeId,
              decoration: InputDecoration(
                labelText: 'Seleccionar tatuador *', // Etiqueta actualizada
                labelStyle: TextStyle(color: _hintColor),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                prefixIcon: Icon(Icons.work_outline, color: _accentColor.withValues(alpha: 0.7)),
                hintText: 'Seleccione un tatuador', // Texto de sugerencia actualizado
                hintStyle: TextStyle(color: _hintColor),
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
              style: TextStyle(color: _textColor),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Debe seleccionar un tatuador'; // Mensaje de validación actualizado
                }
                return null;
              },
              items: _employees.map((employee) {
                return DropdownMenuItem<String>(
                  value: employee['id'],
                  child: Text(employee['username'] ?? 'Sin nombre'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEmployeeId = value;
                });
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _specialtyCtrl,
              style: TextStyle(color: _textColor),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notas adicionales',
                labelStyle: TextStyle(color: _hintColor),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
                prefixIcon: Icon(Icons.note_outlined, color: _accentColor.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
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
                  : Text(
                      _userType == 'client' ? 'Completar Registro' : 'Guardar Perfil',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}