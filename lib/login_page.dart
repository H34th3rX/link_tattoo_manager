import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      // Esta llamada lanzará AuthException si hay error de credenciales
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      // Si llega aquí y hay sesión, login OK
      if (res.session != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        // Casos raros donde no se lanza excepción pero tampoco hay sesión
        setState(() {
          _error = 'No se pudo iniciar sesión. Intenta de nuevo.';
        });
      }
    } on AuthException catch (e) {
      // Capturamos el mensaje de error amigable
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      // Cualquier otro fallo inesperado
      setState(() {
        _error = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}