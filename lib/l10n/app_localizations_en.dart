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
  String get ensureAccountLinked =>
      'Please ensure your account is linked to an employee profile.';

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
  String get appointmentsToday => 'Appointments';

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

  @override
  String get clientsPageTitle => 'Clients Management';

  @override
  String get myClients => 'My Clients';

  @override
  String clientsShown(Object filtered, Object total) {
    return '$filtered of $total clients shown';
  }

  @override
  String get newClient => 'New Client';

  @override
  String get searchClients => 'Search clients by name, email, or phone...';

  @override
  String get showAll => 'Show all';

  @override
  String get onlyActive => 'Only active';

  @override
  String get noClientsFound => 'No clients found';

  @override
  String get trySearchingAll =>
      'Try searching all clients or check the filters';

  @override
  String get onlyActiveClients => 'Only active clients';

  @override
  String get inactiveClientsAvailable =>
      'There are inactive clients available. Tap \'Show all\' to view them.';

  @override
  String get noClientsRegisteredMessage => 'No clients registered';

  @override
  String get addFirstClient => 'Add your first client to get started';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get noNotes => 'No notes';

  @override
  String get viewProfile => 'View profile';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deactivateClient => 'Deactivate client';

  @override
  String get activateClient => 'Activate client';

  @override
  String preferredContact(Object method) {
    return 'Pref: $method';
  }

  @override
  String get noNewNotifications => 'No new notifications';

  @override
  String get close => 'Close';

  @override
  String get editClient => 'Edit Client';

  @override
  String get addClientInfo => 'Add the client\'s information';

  @override
  String get modifyClientInfo => 'Modify the client\'s information';

  @override
  String get fullName => 'Full name';

  @override
  String get additionalNotes => 'Additional notes';

  @override
  String get preferredContactMethod => 'Preferred contact method';

  @override
  String get contactMethodEmail => 'Email';

  @override
  String get contactMethodPhone => 'Phone';

  @override
  String get contactMethodWhatsApp => 'WhatsApp';

  @override
  String get contactMethodSMS => 'SMS';

  @override
  String get createClient => 'Create Client';

  @override
  String get update => 'Update';

  @override
  String get confirmDeletion => 'Confirm deletion';

  @override
  String get deleteClientConfirmation =>
      'Are you sure you want to delete this client?';

  @override
  String get clientCreatedSuccessfully => 'Client created successfully';

  @override
  String get clientUpdatedSuccessfully => 'Client updated successfully';

  @override
  String get clientDeletedSuccessfully => 'Client deleted successfully';

  @override
  String get clientStatusUpdated => 'Client status updated';

  @override
  String get errorLoadingUserData => 'Error loading user data';

  @override
  String get errorLoadingClients =>
      'Error loading clients. Check your connection.';

  @override
  String get errorLoggingOut => 'Error logging out.';

  @override
  String errorSavingClient(Object error) {
    return 'Error saving client: $error';
  }

  @override
  String get errorDeletingClient => 'Error deleting client.';

  @override
  String get errorChangingClientStatus => 'Error changing client status.';

  @override
  String get nameRequired => 'The name is required';

  @override
  String get nameLengthError => 'The name must be between 2 and 50 characters';

  @override
  String get nameFormatError => 'The name can only contain letters and spaces';

  @override
  String get phoneRequired => 'The phone is required';

  @override
  String get phoneFormatError => 'Invalid phone format';

  @override
  String get emailFormatError => 'Invalid email format';

  @override
  String get appTitle => 'LinkTattoo Manager';

  @override
  String get emailOrUsername => 'Email or Username';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign In';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get or => 'OR';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get emailOrUsernameRequired => 'Email or username is required';

  @override
  String get invalidEmailOrUsername =>
      'Enter a valid email or username\n(minimum 3 characters, only letters, numbers, - and _)';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get userSignedOut => 'User signed out';

  @override
  String authError(Object error) {
    return 'Authentication error: $error';
  }

  @override
  String get invalidCredentials =>
      'Invalid credentials. Check your email and password.';

  @override
  String get invalidUsernameCredentials =>
      'Invalid credentials. Check your username and password.';

  @override
  String incorrectPassword(Object username) {
    return 'Incorrect password for user: $username';
  }

  @override
  String get userNotFound =>
      'User not found. Check that the username is correct.';

  @override
  String get databaseConnectionError => 'Database connection error. Try again.';

  @override
  String get unexpectedLoginError => 'Unexpected login error. Try again.';

  @override
  String get profileVerificationError => 'Error verifying profile. Try again.';

  @override
  String get signingInWithGoogle => 'Signing in with Google...';

  @override
  String get signInCancelled => 'Sign in cancelled';

  @override
  String get connectionError => 'Connection error. Check your internet';

  @override
  String get configurationError => 'Configuration error. Contact administrator';

  @override
  String get authTokenError => 'Authentication error. Try again';

  @override
  String get alternativeMethod => 'Alternative method';

  @override
  String get directMethodFailed =>
      'The direct method failed. Do you want to try Google\'s redirect method?';

  @override
  String get tryAgain => 'Try';

  @override
  String alternativeMethodError(Object error) {
    return 'Alternative method error: $error';
  }

  @override
  String get passwordRecoveryInDevelopment =>
      'Password recovery feature in development';

  @override
  String get authErrorInvalidLogin =>
      'Invalid credentials. Check your email or username and password.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Email not confirmed. Check your inbox and confirm your account.';

  @override
  String get authErrorTooManyRequests =>
      'Too many failed attempts. Wait a few minutes before trying again.';

  @override
  String get authErrorUserNotFound => 'User not found. Check your credentials.';

  @override
  String get authErrorInvalidPassword => 'Incorrect password.';

  @override
  String get authErrorSignupDisabled => 'Registration is temporarily disabled.';

  @override
  String get authErrorEmailRateLimit =>
      'Email limit exceeded. Wait before trying again.';

  @override
  String authErrorGeneric(Object message) {
    return 'Authentication error: $message';
  }
}
