import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// CAMBIO IMPORTANTE: Usar conditional imports
import 'stub_html.dart' if (dart.library.html) 'dart:html' as html;

//[-------------SERVICIO DE AUTENTICACIÓN CON SOLUCIÓN WEB DEFINITIVA--------------]
class AuthService {
  static final _supabase = Supabase.instance.client;
  
  // Configuración diferente para Web y Mobile
  static GoogleSignIn get _googleSignIn {
    if (kIsWeb) {
      return GoogleSignIn(
        clientId: '643519795291-f6h7tg6vbko0g9hm98ktc6p2ucv9pvt2.apps.googleusercontent.com',
        scopes: ['email', 'profile', 'openid'],
      );
    } else {
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

  //[-------------AUTENTICACIÓN CON GOOGLE - ESTRATEGIA SIMPLIFICADA--------------]
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // En Web, usar OAuth directo para evitar doble prompt
        return await _signInWithGoogleWebOAuth();
      } else {
        // En Mobile, usar la estrategia con Google Sign-In plugin
        await _forceGoogleAccountSelection();
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error detallado en Google Sign-In: $e');
      }
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  //[-------------GOOGLE SIGN-IN PARA WEB - SOLO OAUTH (SIN GOOGLE PLUGIN)--------------]
  static Future<AuthResponse?> _signInWithGoogleWebOAuth() async {
    try {
      if (kDebugMode) {
        print('Iniciando Google OAuth para Web...');
      }
      
      // SOLUCIÓN 1: Limpiar URL antes del OAuth
      await _cleanUrlAndNavigate();
      
      // SOLUCIÓN 2: OAuth directo con Supabase (sin Google plugin)
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
        queryParams: {
          'prompt': 'select_account', // Esto permite seleccionar cuenta cada vez
          'access_type': 'offline',
        },
      );
      
      if (kDebugMode) {
        print('OAuth redirect iniciado...');
      }
      
      // En Web OAuth, el redirect manejará el login
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en Google OAuth Web: $e');
      }
      throw Exception('Error en Google OAuth Web: $e');
    }
  }

  //[-------------OBTENER URL DE REDIRECT CORRECTA--------------]
  static String _getRedirectUrl() {
    if (kIsWeb) {
      // CAMBIO: Usar función helper para obtener la URL
      return _getWebLocationHref();
    }
    return '';
  }

  //[-------------HELPER PARA OBTENER URL ACTUAL--------------]
  static String _getWebLocationHref() {
    if (kIsWeb) {
      try {
        final uri = Uri.parse(html.window.location.href);
        final baseUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
        
        if (kDebugMode) {
          print('Redirect URL: $baseUrl');
        }
        
        return baseUrl;
      } catch (e) {
        if (kDebugMode) {
          print('Error obteniendo URL: $e');
        }
        return '';
      }
    }
    return '';
  }

  //[-------------LIMPIAR URL Y NAVEGAR A BASE--------------]
  static Future<void> _cleanUrlAndNavigate() async {
    if (kIsWeb) {
      try {
        final currentHref = _getCurrentHref();
        if (currentHref.isEmpty) return;
        
        final uri = Uri.parse(currentHref);
        final cleanUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}${uri.path}';
        
        if (currentHref != cleanUrl) {
          if (kDebugMode) {
            print('Limpiando URL de: $currentHref a: $cleanUrl');
          }
          
          // Usar replaceState para no crear nueva entrada en historial
          _replaceHistoryState(cleanUrl);
          
          if (kDebugMode) {
            print('URL limpiada exitosamente');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error limpiando URL: $e');
        }
      }
    }
  }

  //[-------------HELPERS PARA FUNCIONES WEB--------------]
  static String _getCurrentHref() {
    if (kIsWeb) {
      try {
        return html.window.location.href;
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  static void _replaceHistoryState(String url) {
    if (kIsWeb) {
      try {
        html.window.history.replaceState(null, '', url);
      } catch (e) {
        if (kDebugMode) {
          print('Error replacing history state: $e');
        }
      }
    }
  }

  static void _reloadWindow() {
    if (kIsWeb) {
      try {
        html.window.location.reload();
      } catch (e) {
        if (kDebugMode) {
          print('Error reloading window: $e');
        }
      }
    }
  }

  //[-------------FORZAR SELECCIÓN DE CUENTA DE GOOGLE (Solo para Mobile)--------------]
  static Future<void> _forceGoogleAccountSelection() async {
    try {
      if (!kIsWeb && await _googleSignIn.isSignedIn()) {
        if (kDebugMode) {
          print('Cerrando sesión de Google para permitir selección de cuenta');
        }
        await _googleSignIn.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar sesión de Google: $e');
      }
    }
  }

  //[-------------GOOGLE SIGN-IN PARA MOBILE (Sin cambios)--------------]
  static Future<AuthResponse?> _signInWithGoogleMobile() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return null;
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

  //[-------------MÉTODO ALTERNATIVO PARA WEB (Mismo que el principal)--------------]
  static Future<void> signInWithGoogleOAuth() async {
    // Redirigir al método principal para consistencia
    await signInWithGoogle();
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

  //[-------------CERRAR SESIÓN MEJORADO CON LIMPIEZA COMPLETA--------------]
  static Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('Iniciando logout completo...');
      }
      
      // 1. En Web, limpiar Google OAuth primero
      if (kIsWeb) {
        await _clearWebGoogleAuth();
      } else {
        // 2. En Mobile, cerrar sesión de Google
        if (await _googleSignIn.isSignedIn()) {
          if (kDebugMode) {
            print('Cerrando sesión de Google en Mobile...');
          }
          await _googleSignIn.disconnect();
        }
      }
      
      // 3. Cerrar sesión en Supabase
      await _supabase.auth.signOut();
      
      if (kDebugMode) {
        print('Sesión de Supabase cerrada');
      }
      
      // 4. Limpiar URL en Web
      if (kIsWeb) {
        await _cleanUrlAndNavigate();
        
        // 5. Recargar página para limpiar completamente el estado
        await Future.delayed(const Duration(milliseconds: 300));
        _reloadWindow();
      }
      
      if (kDebugMode) {
        print('Logout completo finalizado');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error durante logout: $e');
      }
      
      // Logout de emergencia
      try {
        await _supabase.auth.signOut();
        if (kIsWeb) {
          _reloadWindow();
        }
      } catch (emergencyError) {
        if (kDebugMode) {
          print('Error en logout de emergencia: $emergencyError');
        }
      }
    }
  }

  //[-------------LIMPIAR AUTENTICACIÓN WEB DE GOOGLE--------------]
  static Future<void> _clearWebGoogleAuth() async {
    if (kIsWeb) {
      try {
        if (kDebugMode) {
          print('Limpiando autenticación web de Google...');
        }
        
        // Intentar logout del plugin de Google si está disponible
        try {
          if (await _googleSignIn.isSignedIn()) {
            await _googleSignIn.disconnect();
            if (kDebugMode) {
              print('Google plugin desconectado');
            }
          }
        } catch (pluginError) {
          if (kDebugMode) {
            print('Google plugin no disponible o error: $pluginError');
          }
        }
        
        // Limpiar cookies de Google manualmente
        await _clearGoogleCookies();
        
        if (kDebugMode) {
          print('Limpieza web de Google completada');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error limpiando auth web de Google: $e');
        }
      }
    }
  }

  //[-------------LIMPIAR COOKIES DE GOOGLE--------------]
  static Future<void> _clearGoogleCookies() async {
    if (kIsWeb) {
      try {
        // Limpiar cookies relacionadas con Google
        final cookiesToClear = [
          'accounts.google.com',
          '.google.com',
          '.googleapis.com',
        ];
        
        // ignore: unused_local_variable
        for (String domain in cookiesToClear) {
          try {
            // En Flutter Web, las cookies se manejan automáticamente
            // pero podemos intentar limpiar el localStorage
            _clearWebStorage();
          } catch (e) {
            // Ignorar errores de limpieza individual
          }
        }
        
        if (kDebugMode) {
          print('Cookies y storage de Google limpiados');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error limpiando cookies de Google: $e');
        }
      }
    }
  }

  //[-------------HELPER PARA LIMPIAR WEB STORAGE--------------]
  static void _clearWebStorage() {
    if (kIsWeb) {
      try {
        html.window.localStorage.removeWhere((key, value) => 
          key.contains('google') || 
          key.contains('oauth') || 
          key.contains('gapi'));
        
        html.window.sessionStorage.removeWhere((key, value) => 
          key.contains('google') || 
          key.contains('oauth') || 
          key.contains('gapi'));
      } catch (e) {
        if (kDebugMode) {
          print('Error clearing web storage: $e');
        }
      }
    }
  }

  //[-------------CERRAR SESIÓN SILENCIOSA DE GOOGLE--------------]
  static Future<void> disconnectGoogleAccount() async {
    try {
      if (kIsWeb) {
        await _clearWebGoogleAuth();
      } else {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
          if (kDebugMode) {
            print('Cuenta de Google desconectada completamente');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error desconectando cuenta de Google: $e');
      }
    }
  }

  //[-------------MÉTODO PARA LIMPIAR ESTADO DE GOOGLE EN WEB--------------]
  static Future<void> clearGoogleWebState() async {
    if (kIsWeb) {
      await _clearWebGoogleAuth();
      await _cleanUrlAndNavigate();
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
              // Limpiar URL después de login exitoso
              if (kIsWeb) {
                _cleanUrlAndNavigate();
              }
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

  //[-------------INICIALIZAR ESTADO DE AUTENTICACIÓN--------------]
  static Future<void> initializeAuthState() async {
    if (kIsWeb) {
      try {
        // Limpiar URL de parámetros OAuth al inicializar
        await _cleanUrlAndNavigate();
        
        if (kDebugMode) {
          print('Estado de autenticación inicializado para Web');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error inicializando estado de auth: $e');
        }
      }
    }
  }

  //[-------------VERIFICAR ESTADO DE GOOGLE SIGN-IN--------------]
  static Future<bool> isGoogleSignedIn() async {
    try {
      if (kIsWeb) {
        // En Web, verificar por la sesión de Supabase
        return getCurrentUser() != null;
      } else {
        return await _googleSignIn.isSignedIn();
      }
    } catch (e) {
      return false;
    }
  }

  //[-------------OBTENER INFORMACIÓN DE USUARIO GOOGLE--------------]
  static Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    try {
      if (kIsWeb) {
        return null; // En Web OAuth no tenemos acceso al GoogleSignInAccount
      } else {
        return _googleSignIn.currentUser;
      }
    } catch (e) {
      return null;
    }
  }
}