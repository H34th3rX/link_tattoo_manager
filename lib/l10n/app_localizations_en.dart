// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profilePageTitle => 'My Profile';

  @override
  String errorLoadingProfile(Object error) {
    return 'Error loading profile: $error';
  }

  @override
  String errorSavingProfile(Object error) {
    return 'Error saving profile: $error';
  }

  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully!';

  @override
  String get notifications => 'Notifications';

  @override
  String get noEmployeeProfileLoaded => 'No employee profile loaded.';

  @override
  String get ensureAccountLinked => 'Please ensure your account is linked to an employee profile.';

  @override
  String get retry => 'Retry';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get languagePreferenceSaved => 'Language preference saved!';

  @override
  String get username => 'Username';

  @override
  String get phone => 'Phone';

  @override
  String get email => 'Email';

  @override
  String get notesBiography => 'Notes / Biography';

  @override
  String get specialty => 'Specialty';

  @override
  String get selectSpecialty => 'Select Specialty';

  @override
  String get customSpecialty => 'Custom Specialty';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get years => 'Years';

  @override
  String get clients => 'Clients';

  @override
  String get thisMonth => 'This Month';

  @override
  String get noAppointments => 'No Appointments';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get nextAppointment => 'Next Appointment';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get appointments => 'Appointments';

  @override
  String get calendar => 'Calendar';

  @override
  String get reports => 'Reports';

  @override
  String get myProfile => 'My Profile';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get logout => 'Logout';

  @override
  String get dashboardPageTitle => 'Dashboard';

  @override
  String get appointmentsToday => 'Appointments Today';

  @override
  String get clientsStat => 'Clients';

  @override
  String get nextAppointmentShort => 'Next';

  @override
  String get income => 'Income';

  @override
  String get newAppointment => 'New Appointment';

  @override
  String get viewAppointments => 'View Appointments';

  @override
  String get calendarAction => 'Calendar';

  @override
  String get weeklyRevenue => 'Weekly Revenue';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get latestClient => 'Latest Client';

  @override
  String get latestAppointment => 'Latest Appointment';

  @override
  String get upcomingAppointments => 'Upcoming Appointments';

  @override
  String get registered => 'Registered';

  @override
  String get noClientsRegistered => 'No clients registered';

  @override
  String get time => 'Time';

  @override
  String get noStatus => 'No Status';

  @override
  String get noAppointmentsRegistered => 'No appointments registered';

  @override
  String get unknownClient => 'Unknown Client';
}
