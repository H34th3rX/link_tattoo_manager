import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

 Future<void> _register() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
    setState(() {
      _error = 'Las contraseñas no coinciden.';
      _loading = false;
    });
    return;
  }

  try {
    final navigator = Navigator.of(context);
    final res = await Supabase.instance.client.auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (res.user != null && mounted) {
      if (mounted) {
        ScaffoldMessenger.of(navigator.context).showSnackBar(
          const SnackBar(content: Text('Registro exitoso. Revisa tu email.')),
        );
      }
      navigator.pushReplacementNamed('/login');
    } else if (mounted) {
      setState(() => _error = 'No se pudo completar el registro.');
    }
  } on AuthException catch (e) {
    if (mounted) setState(() => _error = e.message);
  } catch (e) {
    if (mounted) setState(() => _error = 'Error inesperado: $e');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBDA206);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Fondo difuminado
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  const Color.fromRGBO(0, 0, 0, 0.7),
                  BlendMode.dstATop,
                ),
              ),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: const Color.fromRGBO(0, 0, 0, 0.2)),
            ),
          ),
        ),

        // 📌 Contenido centrado
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600;

              return SingleChildScrollView(
                physics: isWideScreen ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔹 Ajustar tamaño del logo en pantallas grandes
                      Image.asset(
                        'assets/images/logo.png',
                        height: isWideScreen ? 150 : 275,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Título
                      const Center(
                        child: Text(
                          'Registro',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 🔹 Error
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // 🔹 Campos
                      _buildTextField(controller: _usernameCtrl, label: 'Usuario', icon: Icons.person),
                      _buildTextField(controller: _emailCtrl, label: 'Dirección de email', icon: Icons.email),
                      _buildTextField(controller: _passwordCtrl, label: 'Contraseña', icon: Icons.lock, obscure: true),
                      _buildTextField(controller: _confirmPasswordCtrl, label: 'Verificar Contraseña', icon: Icons.lock, obscure: true),
                      const SizedBox(height: 24),

                      // 🔹 Botón Registrarse
                      _buildButton(
                        text: 'Registrarse',
                        onPressed: _loading ? null : _register,
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Enlace de inicio de sesión
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            '¿Ya tienes una cuenta? Inicia Sesión',
                            style: TextStyle(fontSize: 12, color: accent),
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
      ]),
    );
  }

  // 🏗️ Modularizando los componentes
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.black87,
          prefixIcon: Icon(icon, color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBDA206),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.black))
            : Text(text, style: const TextStyle(fontSize: 16, color: Colors.black)),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }
}
