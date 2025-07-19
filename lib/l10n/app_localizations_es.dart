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
  String get noEmployeeProfileLoaded => 'No se ha cargado el perfil del empleado.';

  @override
  String get ensureAccountLinked => 'Por favor, asegúrate de que tu cuenta esté vinculada a un perfil de empleado.';

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
}
