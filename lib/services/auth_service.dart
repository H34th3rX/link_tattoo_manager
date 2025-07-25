import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

//[-------------SERVICIO DE AUTENTICACIÓN ROBUSTO--------------]
class AuthService {
  static final _supabase = Supabase.instance.client;
  
  // Configuración diferente para Web y Mobile
  static GoogleSignIn get _googleSignIn {
    if (kIsWeb) {
      // Para Web: usar solo el Web Client ID con configuración más específica
      return GoogleSignIn(
        clientId: '643519795291-f6h7tg6vbko0g9hm98ktc6p2ucv9pvt2.apps.googleusercontent.com',
        scopes: ['email', 'profile', 'openid'],
      );
    } else {
      // Para Android: usar el Server Client ID (Web Client ID)
      return GoogleSignIn(
        serverClientId: '643519795291-f6h7tg6vbko0g9hm98ktc6p2ucv9pvt2.apps.googleusercontent.com',
        scopes: ['email', 'profile', 'openid'],
      );
    }
  }

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

  //[-------------AUTENTICACIÓN CON GOOGLE MULTI-ESTRATEGIA--------------]
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      // IMPORTANTE: Cerrar sesión de Google primero para forzar selección de cuenta
      await _forceGoogleAccountSelection();
      
      if (kIsWeb) {
        // En Web, intentar múltiples estrategias
        return await _signInWithGoogleWeb();
      } else {
        // En Mobile, usar estrategia nativa
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error detallado en Google Sign-In: $e');
      }
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  //[-------------FORZAR SELECCIÓN DE CUENTA DE GOOGLE--------------]
  static Future<void> _forceGoogleAccountSelection() async {
    try {
      // Verificar si hay una sesión activa de Google
      if (await _googleSignIn.isSignedIn()) {
        if (kDebugMode) {
          print('Cerrando sesión de Google para permitir selección de cuenta');
        }
        await _googleSignIn.signOut();
        
        // Pequeña pausa para asegurar que el signOut se complete
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar sesión de Google: $e');
      }
      // No lanzar error aquí, continuar con el proceso de login
    }
  }

  //[-------------GOOGLE SIGN-IN PARA WEB CON MÚLTIPLES ESTRATEGIAS--------------]
  static Future<AuthResponse?> _signInWithGoogleWeb() async {
    try {
      // Estrategia 1: Intentar con google_sign_in primero
      try {
        // Configurar para forzar selección de cuenta en Web
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          return null; // Usuario canceló
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        if (kDebugMode) {
          print('ID Token existe: ${googleAuth.idToken != null}');
          print('Access Token existe: ${googleAuth.accessToken != null}');
          print('Usuario seleccionado: ${googleUser.email}');
        }

        if (googleAuth.idToken != null) {
          // Si tenemos ID token, usar signInWithIdToken
          final AuthResponse response = await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: googleAuth.idToken!,
            accessToken: googleAuth.accessToken,
          );
          return response;
        } else {
          // Si no hay ID token, intentar con OAuth
          throw Exception('ID Token no disponible, intentando OAuth');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Estrategia 1 falló: $e');
        }
        
        // Estrategia 2: Usar Supabase OAuth como fallback con selección de cuenta
        if (kDebugMode) {
          print('Intentando con Supabase OAuth...');
        }
        
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/',
          queryParams: {
            'prompt': 'select_account', // Forzar selección de cuenta
          },
        );
        
        // En OAuth, la respuesta será manejada por el redirect
        return null;
      }
    } catch (e) {
      throw Exception('Error en Google Sign-In Web: $e');
    }
  }

  //[-------------GOOGLE SIGN-IN PARA MOBILE--------------]
  static Future<AuthResponse?> _signInWithGoogleMobile() async {
    try {
      // En mobile, después del signOut anterior, esto forzará la selección
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null; // Usuario canceló
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (kDebugMode) {
        print('Mobile - ID Token existe: ${googleAuth.idToken != null}');
        print('Mobile - Access Token existe: ${googleAuth.accessToken != null}');
        print('Mobile - Usuario seleccionado: ${googleUser.email}');
      }

      if (googleAuth.idToken == null) {
        throw Exception('No se pudo obtener el token de Google en Android');
      }

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      return response;
    } catch (e) {
      throw Exception('Error en Google Sign-In Mobile: $e');
    }
  }

  //[-------------MÉTODO ALTERNATIVO PARA WEB (Solo OAuth)--------------]
  static Future<void> signInWithGoogleOAuth() async {
    try {
      // Asegurar que no haya sesión activa antes del OAuth
      await _forceGoogleAccountSelection();
      
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        queryParams: {
          'prompt': 'select_account', // Forzar selección de cuenta
        },
      );
    } catch (e) {
      throw Exception('Error en Google OAuth: $e');
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
    try {
      // Cerrar sesión en Google si está activo
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        if (kDebugMode) {
          print('Sesión de Google cerrada');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cerrando sesión de Google: $e');
      }
    }
    
    // Cerrar sesión en Supabase
    await _supabase.auth.signOut();
    if (kDebugMode) {
      print('Sesión de Supabase cerrada');
    }
  }

  //[-------------CERRAR SESIÓN SILENCIOSA DE GOOGLE (para cambio de cuenta)--------------]
  static Future<void> disconnectGoogleAccount() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
        if (kDebugMode) {
          print('Cuenta de Google desconectada completamente');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error desconectando cuenta de Google: $e');
      }
    }
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

  //[-------------VERIFICAR ESTADO DE GOOGLE SIGN-IN--------------]
  static Future<bool> isGoogleSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      return false;
    }
  }

  //[-------------OBTENER INFORMACIÓN DE USUARIO GOOGLE--------------]
  static Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    try {
      return _googleSignIn.currentUser;
    } catch (e) {
      return null;
    }
  }

  //[-------------SETUP LISTENER PARA AUTH STATE CHANGES--------------]
  static void setupAuthListener({
    required Function(User user) onSignIn,
    required Function() onSignOut,
    required Function(String error) onError,
  }) {
    _supabase.auth.onAuthStateChange.listen((data) {
      try {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (kDebugMode) {
          print('Auth State Change: $event');
          if (session?.user != null) {
            print('Usuario: ${session!.user.email}');
          }
        }

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session?.user != null) {
              onSignIn(session!.user);
            }
            break;
          case AuthChangeEvent.signedOut:
            onSignOut();
            break;
          case AuthChangeEvent.tokenRefreshed:
            if (session?.user != null && kDebugMode) {
              if (kDebugMode) {
                print('Token refreshed for user: ${session!.user.email}');
              }
            }
            break;
          default:
            break;
        }
      } catch (e) {
        onError('Error en auth state change: $e');
      }
    });
  }
}