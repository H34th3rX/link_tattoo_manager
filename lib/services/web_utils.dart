// web_utils.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Limpia las cookies relacionadas con la autenticación de Google en el navegador.
/// Esto es crucial para forzar la selección de cuenta en Google OAuth.
void clearGoogleCookiesWeb() {
  try {
    // Usar JavaScript directo para limpiar cookies de Google
    _clearGoogleCookiesJS();
  } catch (e) {
    // Si falla, intentar método alternativo
    print('Error limpiando cookies de Google: $e');
  }
}

/// Recarga la ventana del navegador.
void reloadWindowUtil() {
  web.window.location.reload();
}

/// Obtiene la URL actual del navegador.
String getCurrentHrefUtil() {
  return web.window.location.href;
}

/// Obtiene la URL base para redirección.
String getWebLocationHrefUtil() {
  return web.window.location.href;
}

/// Reemplaza el estado del historial del navegador sin recargar la página.
/// Útil para limpiar parámetros de URL después de un redirect de OAuth.
void replaceHistoryStateUtil(String url) {
  web.window.history.replaceState(null, '', url);
}

// Función JavaScript externa para limpiar cookies
@JS('clearGoogleCookies')
external void _clearGoogleCookiesJS();

// Inyectar el código JavaScript necesario
@JS('eval')
external void _eval(String code);

// Inicializar el código JavaScript cuando se carga el módulo
void _initializeJavaScript() {
  _eval('''
    window.clearGoogleCookies = function() {
      // Limpiar cookies específicas de Google OAuth
      var cookies = document.cookie.split(';');
      for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i];
        var eqPos = cookie.indexOf('=');
        var name = eqPos > -1 ? cookie.substr(0, eqPos).trim() : cookie.trim();
        
        // Identificar y limpiar cookies específicas de Google OAuth
        if (name.startsWith('G_AUTHUSER_ID') || 
            name.startsWith('G_ENABLED_IDPS') ||
            name.startsWith('__Secure-1PSID') ||
            name.startsWith('__Secure-3PSID') ||
            name.startsWith('SAPISID') ||
            name.startsWith('APISID') ||
            name.startsWith('SSID') ||
            name.startsWith('HSID') ||
            name.startsWith('SID')) {
          
          // Limpiar la cookie estableciendo una fecha de expiración en el pasado
          document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=.google.com;';
          document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=.googleapis.com;';
          document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        }
      }
      
      // Limpiar también localStorage y sessionStorage relacionado con Google
      try {
        var keysToRemove = [];
        for (var i = 0; i < localStorage.length; i++) {
          var key = localStorage.key(i);
          if (key && (key.includes('google') || key.includes('oauth') || key.includes('supabase.auth'))) {
            keysToRemove.push(key);
          }
        }
        keysToRemove.forEach(function(key) {
          localStorage.removeItem(key);
        });
        
        // Hacer lo mismo para sessionStorage
        keysToRemove = [];
        for (var i = 0; i < sessionStorage.length; i++) {
          var key = sessionStorage.key(i);
          if (key && (key.includes('google') || key.includes('oauth') || key.includes('supabase.auth'))) {
            keysToRemove.push(key);
          }
        }
        keysToRemove.forEach(function(key) {
          sessionStorage.removeItem(key);
        });
      } catch (e) {
        console.log('Error limpiando storage:', e);
      }
    };
  ''');
}

// Clase para inicializar automáticamente el JavaScript
class _WebUtilsInitializer {
  static bool _initialized = false;
  
  static void ensureInitialized() {
    if (!_initialized) {
      _initializeJavaScript();
      _initialized = true;
    }
  }
}

// Función pública para asegurar la inicialización
void ensureWebUtilsInitialized() {
  _WebUtilsInitializer.ensureInitialized();
}
