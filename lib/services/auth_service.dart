import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

//[-------------SERVICIO DE AUTENTICACIÓN--------------]
class AuthService {
  static final _supabase = Supabase.instance.client;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '643519795291-f6h7tg6vbko0g9hm98ktc6p2ucv9pvt2.apps.googleusercontent.com',
  );

  //[-------------AUTENTICACIÓN CON EMAIL/PASSWORD--------------]
  static Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  //[-------------AUTENTICACIÓN CON GOOGLE--------------]
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      // Iniciar sesión con Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // El usuario canceló el inicio de sesión
        return null;
      }

      // Obtener los detalles de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('No se pudo obtener el token de Google');
      }

      // Autenticar con Supabase usando el token de Google
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      return response;
    } catch (e) {
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  //[-------------REGISTRO CON EMAIL/PASSWORD--------------]
  static Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  //[-------------CERRAR SESIÓN--------------]
  static Future<void> signOut() async {
    // Cerrar sesión en Google si está activo
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    
    // Cerrar sesión en Supabase
    await _supabase.auth.signOut();
  }

  //[-------------OBTENER USUARIO ACTUAL--------------]
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  //[-------------VERIFICAR SI EL PERFIL EXISTE--------------]
  static Future<Map<String, dynamic>?> getEmployeeProfile(String userId) async {
    final response = await _supabase
        .from('employees')
        .select('id, username')
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  //[-------------BUSCAR USUARIO POR USERNAME--------------]
  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final response = await _supabase
        .from('employees')
        .select('email, username, id')
        .eq('username', username)
        .maybeSingle();
    return response;
  }
}