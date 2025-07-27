// web_utils_stub.dart
// Este archivo se usa cuando dart.library.html NO está disponible (ej. mobile)

/// Limpia las cookies relacionadas con la autenticación de Google en el navegador.
/// En entornos no web, esta función no hace nada.
void clearGoogleCookiesWeb() {
  // No-op para entornos no web
}

/// Recarga la ventana del navegador.
/// En entornos no web, esta función no hace nada.
void reloadWindowUtil() {
  // No-op para entornos no web
}

/// Obtiene la URL actual del navegador.
/// En entornos no web, devuelve una cadena vacía o un valor predeterminado.
String getCurrentHrefUtil() {
  return ''; // O un valor predeterminado adecuado para mobile
}

/// Obtiene la URL base para redirección.
/// En entornos no web, devuelve una cadena vacía o un valor predeterminado.
String getWebLocationHrefUtil() {
  return ''; // O un valor predeterminado adecuado para mobile
}

/// Reemplaza el estado del historial del navegador sin recargar la página.
/// En entornos no web, esta función no hace nada.
void replaceHistoryStateUtil(String url) {
  // No-op para entornos no web
}

/// Función para asegurar la inicialización de utilidades web.
/// En entornos no web, esta función no hace nada.
void ensureWebUtilsInitialized() {
  // No-op para entornos no web
}
