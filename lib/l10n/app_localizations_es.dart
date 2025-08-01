// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get profilePageTitle => 'Mi Perfil';

  @override
  String errorLoadingProfile(Object error) {
    return 'Error al cargar el perfil: $error';
  }

  @override
  String errorSavingProfile(Object error) {
    return 'Error al guardar el perfil: $error';
  }

  @override
  String get profileUpdatedSuccessfully => '¡Perfil actualizado exitosamente!';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get noEmployeeProfileLoaded =>
      'No se ha cargado el perfil del empleado.';

  @override
  String get ensureAccountLinked =>
      'Por favor, asegúrate de que tu cuenta esté vinculada a un perfil de empleado.';

  @override
  String get retry => 'Reintentar';

  @override
  String get editProfile => 'Editar Perfil';

  @override
  String get languageSettings => 'Configuración de Idioma';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get systemDefault => 'Predeterminado del Sistema';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get languagePreferenceSaved => '¡Preferencia de idioma guardada!';

  @override
  String get username => 'Nombre de Usuario';

  @override
  String get phone => 'Teléfono';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get notesBiography => 'Notas / Biografía';

  @override
  String get specialty => 'Especialidad';

  @override
  String get selectSpecialty => 'Seleccionar Especialidad';

  @override
  String get customSpecialty => 'Especialidad Personalizada';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get years => 'Años';

  @override
  String get clients => 'Clientes';

  @override
  String get thisMonth => 'Este Mes';

  @override
  String get noAppointments => 'Sin Citas';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get nextAppointment => 'Próxima Cita';

  @override
  String get dashboard => 'Panel';

  @override
  String get appointments => 'Citas';

  @override
  String get calendar => 'Calendario';

  @override
  String get reports => 'Reportes';

  @override
  String get myProfile => 'Mi Perfil';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get logout => 'Cerrar Sesión';

  @override
  String get dashboardPageTitle => 'Panel';

  @override
  String get appointmentsToday => 'Citas Hoy';

  @override
  String get clientsStat => 'Clientes';

  @override
  String get nextAppointmentShort => 'Próxima';

  @override
  String get income => 'Ingresos';

  @override
  String get newAppointment => 'Nueva Cita';

  @override
  String get viewAppointments => 'Ver Citas';

  @override
  String get calendarAction => 'Calendario';

  @override
  String get weeklyRevenue => 'Ingresos de la Semana';

  @override
  String get recentActivity => 'Actividad Reciente';

  @override
  String get latestClient => 'Último Cliente';

  @override
  String get latestAppointment => 'Última Cita';

  @override
  String get upcomingAppointments => 'Próximas Citas';

  @override
  String get registered => 'Registrado';

  @override
  String get noClientsRegistered => 'No hay clientes registrados';

  @override
  String get time => 'Hora';

  @override
  String get noStatus => 'Sin Estado';

  @override
  String get noAppointmentsRegistered => 'No hay citas registradas';

  @override
  String get unknownClient => 'Cliente Desconocido';

  @override
  String get clientsPageTitle => 'Gestión de Clientes';

  @override
  String get myClients => 'Mis Clientes';

  @override
  String clientsShown(Object filtered, Object total) {
    return '$filtered de $total clientes mostrados';
  }

  @override
  String get newClient => 'Nuevo Cliente';

  @override
  String get searchClients => 'Buscar clientes por nombre, email o teléfono...';

  @override
  String get showAll => 'Mostrar todos';

  @override
  String get onlyActive => 'Solo activos';

  @override
  String get noClientsFound => 'No se encontraron clientes';

  @override
  String get trySearchingAll =>
      'Intenta buscar en todos los clientes o revisa los filtros';

  @override
  String get onlyActiveClients => 'Solo clientes activos';

  @override
  String get inactiveClientsAvailable =>
      'Hay clientes inactivos disponibles. Toca \'Mostrar todos\' para verlos.';

  @override
  String get noClientsRegisteredMessage => 'No clientes registrados';

  @override
  String get addFirstClient => 'Agrega tu primer cliente para comenzar';

  @override
  String get active => 'Activo';

  @override
  String get inactive => 'Inactivo';

  @override
  String get notSpecified => 'No especificado';

  @override
  String get noNotes => 'Sin notas';

  @override
  String get viewProfile => 'Ver perfil';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get deactivateClient => 'Desactivar cliente';

  @override
  String get activateClient => 'Activar cliente';

  @override
  String preferredContact(Object method) {
    return 'Pref: $method';
  }

  @override
  String get noNewNotifications => 'No hay notificaciones nuevas';

  @override
  String get close => 'Cerrar';

  @override
  String get editClient => 'Editar Cliente';

  @override
  String get addClientInfo => 'Agrega la información del cliente';

  @override
  String get modifyClientInfo => 'Modifica los datos del cliente';

  @override
  String get fullName => 'Nombre completo';

  @override
  String get additionalNotes => 'Notas adicionales';

  @override
  String get preferredContactMethod => 'Método de contacto preferido';

  @override
  String get contactMethodEmail => 'Email';

  @override
  String get contactMethodPhone => 'Teléfono';

  @override
  String get contactMethodWhatsApp => 'WhatsApp';

  @override
  String get contactMethodSMS => 'SMS';

  @override
  String get createClient => 'Crear Cliente';

  @override
  String get update => 'Actualizar';

  @override
  String get confirmDeletion => 'Confirmar eliminación';

  @override
  String get deleteClientConfirmation =>
      '¿Estás seguro de que quieres eliminar este cliente?';

  @override
  String get clientCreatedSuccessfully => 'Cliente creado exitosamente';

  @override
  String get clientUpdatedSuccessfully => 'Cliente actualizado exitosamente';

  @override
  String get clientDeletedSuccessfully => 'Cliente eliminado exitosamente';

  @override
  String get clientStatusUpdated => 'Estado del cliente actualizado';

  @override
  String get errorLoadingUserData => 'Error al cargar datos del usuario';

  @override
  String get errorLoadingClients =>
      'Error al cargar los clientes. Verifica tu conexión.';

  @override
  String get errorLoggingOut => 'Error al cerrar sesión.';

  @override
  String errorSavingClient(Object error) {
    return 'Error al guardar el cliente: $error';
  }

  @override
  String get errorDeletingClient => 'Error al eliminar el cliente.';

  @override
  String get errorChangingClientStatus =>
      'Error al cambiar el estado del cliente.';

  @override
  String get nameRequired => 'El nombre es requerido';

  @override
  String get nameLengthError => 'El nombre debe tener entre 2 y 50 caracteres';

  @override
  String get nameFormatError =>
      'El nombre solo puede contener letras y espacios';

  @override
  String get phoneRequired => 'El teléfono es requerido';

  @override
  String get phoneFormatError => 'Formato de teléfono no válido';

  @override
  String get emailFormatError => 'Formato de email no válido';

  @override
  String get appTitle => 'LinkTattoo Manager';

  @override
  String get emailOrUsername => 'Email o Nombre de usuario';

  @override
  String get password => 'Contraseña';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get or => 'O';

  @override
  String get dontHaveAccount => '¿No tienes una cuenta? ';

  @override
  String get signUp => 'Regístrate';

  @override
  String get emailOrUsernameRequired =>
      'El email o nombre de usuario es requerido';

  @override
  String get invalidEmailOrUsername =>
      'Ingresa un email válido o un nombre de usuario\n(mínimo 3 caracteres, solo letras, números, - y _)';

  @override
  String get passwordRequired => 'La contraseña es requerida';

  @override
  String get passwordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get userSignedOut => 'Usuario cerró sesión';

  @override
  String authError(Object error) {
    return 'Error de autenticación: $error';
  }

  @override
  String get invalidCredentials =>
      'Credenciales inválidas. Verifica tu email y contraseña.';

  @override
  String get invalidUsernameCredentials =>
      'Credenciales inválidas. Verifica tu nombre de usuario y contraseña.';

  @override
  String incorrectPassword(Object username) {
    return 'Contraseña incorrecta para el usuario: $username';
  }

  @override
  String get userNotFound =>
      'Usuario no encontrado. Verifica que el nombre de usuario sea correcto.';

  @override
  String get databaseConnectionError =>
      'Error de conexión con la base de datos. Intenta de nuevo.';

  @override
  String get unexpectedLoginError =>
      'Error inesperado al iniciar sesión. Intenta de nuevo.';

  @override
  String get profileVerificationError =>
      'Error al verificar el perfil. Intenta de nuevo.';

  @override
  String get signingInWithGoogle => 'Iniciando sesión con Google...';

  @override
  String get signInCancelled => 'Inicio de sesión cancelado';

  @override
  String get connectionError => 'Error de conexión. Verifica tu internet';

  @override
  String get configurationError =>
      'Error de configuración. Contacta al administrador';

  @override
  String get authTokenError => 'Error de autenticación. Intenta de nuevo';

  @override
  String get alternativeMethod => 'Método alternativo';

  @override
  String get directMethodFailed =>
      'El método directo falló. ¿Quieres intentar con el método de redirección de Google?';

  @override
  String get tryAgain => 'Intentar';

  @override
  String alternativeMethodError(Object error) {
    return 'Error en método alternativo: $error';
  }

  @override
  String get passwordRecoveryInDevelopment =>
      'Función de recuperación en desarrollo';

  @override
  String get authErrorInvalidLogin =>
      'Credenciales inválidas. Verifica tu email o nombre de usuario y contraseña.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Email no confirmado. Revisa tu bandeja de entrada y confirma tu cuenta.';

  @override
  String get authErrorTooManyRequests =>
      'Demasiados intentos fallidos. Espera unos minutos antes de intentar de nuevo.';

  @override
  String get authErrorUserNotFound =>
      'Usuario no encontrado. Verifica tus credenciales.';

  @override
  String get authErrorInvalidPassword => 'Contraseña incorrecta.';

  @override
  String get authErrorSignupDisabled =>
      'El registro está temporalmente deshabilitado.';

  @override
  String get authErrorEmailRateLimit =>
      'Límite de emails excedido. Espera antes de intentar de nuevo.';

  @override
  String authErrorGeneric(Object message) {
    return 'Error de autenticación: $message';
  }

  @override
  String get unexpectedGoogleError =>
      'Error inesperado en el inicio de sesión con Google';

  @override
  String get googleError => 'Error de Google';

  @override
  String get changeAccountMessage =>
      'Podría haber un problema con tu cuenta de Google. ¿Te gustaría intentar con una cuenta diferente o usar el método alternativo?';

  @override
  String get changeAccount => 'Cambiar Cuenta';

  @override
  String get retryError => 'Error al reintentar el inicio de sesión';

  @override
  String get emailLabel => 'Dirección de correo';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get registerTitle => 'Registro';

  @override
  String get confirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get passwordComplexity =>
      'La contraseña debe contener al menos una letra y un número';

  @override
  String get confirmPasswordRequired => 'Confirma tu contraseña';

  @override
  String get passwordsDontMatch => 'Las contraseñas no coinciden';

  @override
  String get emailRequired => 'El correo es requerido';

  @override
  String get invalidEmail => 'Ingresa un correo válido';

  @override
  String get accountCreated =>
      'Cuenta creada. Se ha enviado un correo de verificación.';

  @override
  String get accountCreationFailed =>
      'No se pudo crear la cuenta. Intenta de nuevo.';

  @override
  String get unexpectedError =>
      'Error inesperado. Verifica tu conexión a internet.';

  @override
  String get userAlreadyRegistered =>
      'Este correo ya está registrado. Intenta iniciar sesión.';

  @override
  String get invalidEmailFormat => 'El formato del correo es inválido.';

  @override
  String get ok => 'OK';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? ';

  @override
  String get passwordRecovery => 'Recuperar Contraseña';

  @override
  String get passwordRecoveryTitle => 'Restablecer Contraseña';

  @override
  String get passwordRecoverySubtitle =>
      'Ingresa tu correo electrónico para restablecer tu contraseña';

  @override
  String get enterEmail => 'Ingresa tu correo electrónico';

  @override
  String get sendRecoveryEmail => 'Enviar Correo de Recuperación';

  @override
  String get backToLogin => 'Volver al Inicio de Sesión';

  @override
  String get emailSent => 'Correo Enviado';

  @override
  String get recoveryEmailSent =>
      'Se ha enviado un correo de recuperación a tu dirección de email. Revisa tu bandeja de entrada.';

  @override
  String get userNotFoundOrGoogle =>
      'Usuario no encontrado o registrado con Google';

  @override
  String get googleUserNoPassword =>
      'Este usuario está registrado con Google y no necesita restablecer contraseña';

  @override
  String get verifyingUser => 'Verificando usuario...';

  @override
  String get sendingEmail => 'Enviando correo...';

  @override
  String get emailNotValid => 'El formato del correo electrónico no es válido';

  @override
  String get recoveryError => 'Error al enviar el correo de recuperación';

  @override
  String get checkYourEmail => 'Revisa tu correo';

  @override
  String get recoveryLinkSent => 'Se ha enviado un enlace de recuperación a';

  @override
  String get didntReceiveEmail => '¿No recibiste el correo?';

  @override
  String get resendEmail => 'Reenviar correo';

  @override
  String get setNewPassword => 'Establecer Nueva Contraseña';

  @override
  String get setNewPasswordSubtitle =>
      'Ingresa tu nueva contraseña a continuación';

  @override
  String get newPassword => 'Nueva Contraseña';

  @override
  String get confirmPassword => 'Confirmar Contraseña';

  @override
  String get updatePassword => 'Actualizar Contraseña';

  @override
  String get passwordUpdatedTitle => '¡Contraseña Actualizada!';

  @override
  String get passwordUpdatedMessage =>
      'Tu contraseña ha sido actualizada exitosamente. Serás redirigido a la página de inicio de sesión.';

  @override
  String get newPasswordDifferent =>
      'La nueva contraseña debe ser diferente a la anterior';

  @override
  String get passwordUpdateError => 'Error al actualizar la contraseña';

  @override
  String get passwordMaxLength =>
      'La contraseña debe tener menos de 72 caracteres';

  @override
  String get passwordRequirements =>
      'La contraseña debe contener al menos una letra y un número';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get verifyAndContinue => 'Verificar y Continuar';

  @override
  String get cannotResetPassword =>
      'No se puede restablecer la contraseña para este usuario.';

  @override
  String get back => 'Volver';

  @override
  String get contactAdminError =>
      'No se pudo actualizar la contraseña. Contacte al administrador.';

  @override
  String get changePassword => 'Cambiar Contraseña';

  @override
  String get accountCreatedWeb =>
      'Cuenta creada. Revisa tu correo y haz clic en el enlace de confirmación. La página se actualizará automáticamente.';
}
