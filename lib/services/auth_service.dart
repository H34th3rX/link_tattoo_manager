import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// CAMBIO IMPORTANTE: Usar importación condicional para las utilidades web
import 'web_utils_stub.dart' if (dart.library.html) 'web_utils.dart' as web_utils;

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
      rethrow;
    }
  }

  //[-------------GOOGLE SIGN-IN PARA WEB - SOLO OAUTH (SIN GOOGLE PLUGIN)--------------]
  static Future<AuthResponse?> _signInWithGoogleWebOAuth() async {
    try {
      if (kDebugMode) {
        print('Iniciando Google OAuth para Web...');
      }
      
      // Asegurar que las utilidades web estén inicializadas
      if (kIsWeb) {
        web_utils.ensureWebUtilsInitialized();
      }

      // RESTAURAR: Limpiar estado de Google antes del OAuth
      await _clearWebGoogleAuth();
      await _cleanUrlAndNavigate();
      
      // Forzar desconexión del plugin de Google si existe
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.disconnect();
          await Future.delayed(const Duration(milliseconds: 300));
        }
      } catch (e) {
        // Ignorar errores del plugin en web
      }
      
      // OAuth directo con Supabase con parámetros para forzar selección de cuenta
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
        queryParams: {
          'prompt': 'select_account consent', // Forzar selección de cuenta y consentimiento
          'access_type': 'offline',
          'include_granted_scopes': 'true',
        },
      );
      
      if (kDebugMode) {
        print('OAuth redirect iniciado con prompt=select_account...');
      }
      
      // En Web OAuth, el redirect manejará el login
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en Google OAuth Web: $e');
      }
      rethrow;
    }
  }

  //[-------------OBTENER URL DE REDIRECT CORRECTA--------------]
  static String _getRedirectUrl() {
    if (kIsWeb) {
      // CAMBIO: Usar función helper de web_utils para obtener la URL
      return web_utils.getWebLocationHrefUtil();
    }
    return '';
  }

  //[-------------LIMPIAR URL Y NAVEGAR A BASE--------------]
  static Future<void> _cleanUrlAndNavigate() async {
    if (kIsWeb) {
      try {
        // Asegurar que las utilidades web estén inicializadas
        web_utils.ensureWebUtilsInitialized();

        final currentHref = web_utils.getCurrentHrefUtil();
        if (currentHref.isEmpty) return;
        
        final uri = Uri.parse(currentHref);
        final cleanUrl = '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}${uri.path}';
        
        if (currentHref != cleanUrl) {
          if (kDebugMode) {
            print('Limpiando URL de: $currentHref a: $cleanUrl');
          }
          
          // Usar replaceState para no crear nueva entrada en historial
          web_utils.replaceHistoryStateUtil(cleanUrl);
          
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
      rethrow;
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
    
    // 1. Verificar si hay un usuario de Google activo en móvil
    if (!kIsWeb) {
      try {
        final googleUser = await getCurrentGoogleUser();
        if (googleUser != null) {
          if (kDebugMode) {
            print('Cerrando sesión de Google en Mobile para: ${googleUser.email}');
          }
          await _googleSignIn.disconnect().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              if (kDebugMode) {
                print('Timeout en GoogleSignIn.disconnect, continuando...');
              }
              return null;
            },
          );
        } else {
          if (kDebugMode) {
            print('No hay usuario de Google activo, omitiendo desconexión');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al desconectar Google en Mobile: $e');
        }
      }
    }
    
    // 2. Cerrar sesión en Supabase con limpieza completa
    try {
      await _supabase.auth.signOut(scope: SignOutScope.global).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            print('Timeout en Supabase.auth.signOut, continuando...');
          }
        },
      );
      if (kDebugMode) {
        print('Sesión de Supabase cerrada (global scope)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar sesión en Supabase: $e');
      }
    }
    
    // 3. Limpiar URL y recargar en Web
    if (kIsWeb) {
      web_utils.ensureWebUtilsInitialized();
      await _clearWebGoogleAuth();
      await _cleanUrlAndNavigate();
      await Future.delayed(const Duration(milliseconds: 300));
      web_utils.reloadWindowUtil();
    }
    
    if (kDebugMode) {
      print('Logout completo finalizado');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error general durante logout: $e');
    }
    
    // Logout de emergencia
    try {
      await _supabase.auth.signOut(scope: SignOutScope.global).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          if (kDebugMode) {
            print('Timeout en logout de emergencia, continuando...');
          }
        },
      );
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
        
        // 1. Intentar logout del plugin de Google si está disponible
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
        
        // Asegurar que las utilidades web estén inicializadas
        web_utils.ensureWebUtilsInitialized();
        
        // 2. Limpiar cookies y storage de Google usando la nueva utilidad
        web_utils.clearGoogleCookiesWeb(); // Usar el helper de web_utils
        
        // 3. Limpiar cualquier token de Supabase relacionado con Google
        try {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            // Solo hacer signOut si hay un usuario activo
            await _supabase.auth.signOut(scope: SignOutScope.local);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error limpiando sesión local: $e');
          }
        }
        
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
  bool justSignedOut = false; // Bandera para rastrear logout reciente

  _supabase.auth.onAuthStateChange.listen((data) async {
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
          if (justSignedOut) {
            if (kDebugMode) {
              print('Ignorando evento signedIn después de logout');
            }
            justSignedOut = false; // Resetear bandera
            return;
          }
          if (session?.user != null) {
            // Limpiar URL después de login exitoso
            if (kIsWeb) {
              web_utils.ensureWebUtilsInitialized();
              await _cleanUrlAndNavigate();
            }
            onSignIn(session!.user);
          }
          break;
        case AuthChangeEvent.passwordRecovery:
          if (kDebugMode) {
            print('Password recovery event detected');
          }
          // El usuario será redirigido automáticamente por el deep link
          break;
        case AuthChangeEvent.signedOut:
          if (justSignedOut) {
            if (kDebugMode) {
              print('Ignorando evento signedOut repetido');
            }
            return; // Evitar procesar eventos signedOut repetidos
          }
          justSignedOut = true; // Marcar que acabamos de cerrar sesión
          onSignOut();
          if (kDebugMode) {
            print('Usuario desconectado, listener procesado');
          }
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
        web_utils.ensureWebUtilsInitialized(); // Asegurar inicialización
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

  //[-------------VERIFICAR SI USUARIO EXISTE Y PUEDE RESETEAR CONTRASEÑA (USANDO RPC)--------------]
  static Future<Map<String, dynamic>> checkUserCanResetPassword(String email) async {
    try {
      if (kDebugMode) {
        print('Verificando usuario para reset de contraseña: $email');
      }

      // Llamar a la nueva función RPC para obtener el estado del usuario
      final response = await _supabase.rpc('check_user_for_password_reset', params: {
        'user_email': email,
      });
      
      if (kDebugMode) {
        print('Respuesta RPC check_user_for_password_reset: $response');
      }

      // La función RPC ya devuelve el formato deseado
      return {
        'exists': response['exists'] as bool,
        'isGoogleUser': response['is_google_user'] as bool,
        'canReset': response['can_reset'] as bool,
        'message': response['message'] as String,
      };
      
    } catch (e) {
      if (kDebugMode) {
        print('Error en checkUserCanResetPassword RPC: $e');
      }
      // En caso de error, devolver que no puede resetear
      return {
        'exists': false,
        'isGoogleUser': false,
        'canReset': false,
        'message': 'Error inesperado al verificar usuario: $e',
      };
    }
  }

  //[-------------ACTUALIZAR CONTRASEÑA SIN SESIÓN ACTIVA (USANDO RPC)--------------]
  static Future<void> updatePasswordDirectly(String email, String newPassword) async {
    try {
      if (kDebugMode) {
        print('Actualizando contraseña directamente para: $email');
      }

      // Llamar a la función RPC para actualizar la contraseña
      final response = await _supabase.rpc('update_user_password', params: {
        'user_email': email,
        'new_password': newPassword,
      });
      
      if (kDebugMode) {
        print('Contraseña actualizada exitosamente via RPC');
        print('Response: $response');
      }
      
      // Si la RPC devuelve un error, lanzarlo
      if (response != null && response['success'] == false) {
        throw Exception(response['error'] ?? 'Error desconocido al actualizar contraseña');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando contraseña directamente: $e');
      }
      rethrow; // Relanzar el error para que sea manejado por la UI
    }
  }

  //[-------------RECUPERACIÓN DE CONTRASEÑA (MÉTODO ORIGINAL - MANTENIDO PARA COMPATIBILIDAD)--------------]
  static Future<void> resetPassword(String email) async {
    try {
      // Configurar URL de redirección según la plataforma
      final String redirectUrl = kIsWeb 
          ? '${Uri.base.origin}/reset_password' // En web, usar la misma ventana
          : 'io.supabase.flutterquickstart://reset_password'; // En mobile, usar deep link
      
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error enviando email de recuperación: $e');
      }
      rethrow;
    }
  }

  //[-------------VERIFICAR SI USUARIO EXISTE Y ES LOCAL (MÉTODO ORIGINAL - MANTENIDO)--------------]
  static Future<Map<String, dynamic>?> checkUserByEmail(String email) async {
    try {
      final response = await _supabase
          .from('users') // o el nombre de tu tabla de usuarios
          .select('id, email, provider')
          .eq('email', email)
          .maybeSingle();
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error verificando usuario: $e');
      }
      return null;
    }
  }

  //[-------------ACTUALIZAR CONTRASEÑA (para cuando el usuario use el link)--------------]
  static Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (kDebugMode) {
        print('Contraseña actualizada exitosamente');
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error actualizando contraseña: $e');
      }
      rethrow;
    }
  }
}