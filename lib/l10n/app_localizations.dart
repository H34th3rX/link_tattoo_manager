import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @profilePageTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get profilePageTitle;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error loading profile: {error}'**
  String errorLoadingProfile(Object error);

  /// No description provided for @errorSavingProfile.
  ///
  /// In en, this message translates to:
  /// **'Error saving profile: {error}'**
  String errorSavingProfile(Object error);

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noEmployeeProfileLoaded.
  ///
  /// In en, this message translates to:
  /// **'No employee profile loaded.'**
  String get noEmployeeProfileLoaded;

  /// No description provided for @ensureAccountLinked.
  ///
  /// In en, this message translates to:
  /// **'Please ensure your account is linked to an employee profile.'**
  String get ensureAccountLinked;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @languagePreferenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Language preference saved!'**
  String get languagePreferenceSaved;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @notesBiography.
  ///
  /// In en, this message translates to:
  /// **'Notes / Biography'**
  String get notesBiography;

  /// No description provided for @specialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get specialty;

  /// No description provided for @selectSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Select Specialty'**
  String get selectSpecialty;

  /// No description provided for @customSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Custom Specialty'**
  String get customSpecialty;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get years;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No Appointments'**
  String get noAppointments;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @nextAppointment.
  ///
  /// In en, this message translates to:
  /// **'Next Appointment'**
  String get nextAppointment;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @dashboardPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardPageTitle;

  /// No description provided for @appointmentsToday.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsToday;

  /// No description provided for @clientsStat.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clientsStat;

  /// No description provided for @nextAppointmentShort.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextAppointmentShort;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @newAppointment.
  ///
  /// In en, this message translates to:
  /// **'New Appointment'**
  String get newAppointment;

  /// No description provided for @viewAppointments.
  ///
  /// In en, this message translates to:
  /// **'View Appointments'**
  String get viewAppointments;

  /// No description provided for @calendarAction.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarAction;

  /// No description provided for @weeklyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Weekly Revenue'**
  String get weeklyRevenue;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @latestClient.
  ///
  /// In en, this message translates to:
  /// **'Latest Client'**
  String get latestClient;

  /// No description provided for @latestAppointment.
  ///
  /// In en, this message translates to:
  /// **'Latest Appointment'**
  String get latestAppointment;

  /// No description provided for @upcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Appointments'**
  String get upcomingAppointments;

  /// No description provided for @registered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get registered;

  /// No description provided for @noClientsRegistered.
  ///
  /// In en, this message translates to:
  /// **'No clients registered'**
  String get noClientsRegistered;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @noStatus.
  ///
  /// In en, this message translates to:
  /// **'No Status'**
  String get noStatus;

  /// No description provided for @noAppointmentsRegistered.
  ///
  /// In en, this message translates to:
  /// **'No appointments registered'**
  String get noAppointmentsRegistered;

  /// No description provided for @unknownClient.
  ///
  /// In en, this message translates to:
  /// **'Unknown Client'**
  String get unknownClient;

  /// No description provided for @clientsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Clients Management'**
  String get clientsPageTitle;

  /// No description provided for @myClients.
  ///
  /// In en, this message translates to:
  /// **'My Clients'**
  String get myClients;

  /// No description provided for @clientsShown.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total} clients shown'**
  String clientsShown(Object filtered, Object total);

  /// No description provided for @newClient.
  ///
  /// In en, this message translates to:
  /// **'New Client'**
  String get newClient;

  /// No description provided for @searchClients.
  ///
  /// In en, this message translates to:
  /// **'Search clients by name, email, or phone...'**
  String get searchClients;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @onlyActive.
  ///
  /// In en, this message translates to:
  /// **'Only active'**
  String get onlyActive;

  /// No description provided for @noClientsFound.
  ///
  /// In en, this message translates to:
  /// **'No clients found'**
  String get noClientsFound;

  /// No description provided for @trySearchingAll.
  ///
  /// In en, this message translates to:
  /// **'Try searching all clients or check the filters'**
  String get trySearchingAll;

  /// No description provided for @onlyActiveClients.
  ///
  /// In en, this message translates to:
  /// **'Only active clients'**
  String get onlyActiveClients;

  /// No description provided for @inactiveClientsAvailable.
  ///
  /// In en, this message translates to:
  /// **'There are inactive clients available. Tap \'Show all\' to view them.'**
  String get inactiveClientsAvailable;

  /// No description provided for @noClientsRegisteredMessage.
  ///
  /// In en, this message translates to:
  /// **'No clients registered'**
  String get noClientsRegisteredMessage;

  /// No description provided for @addFirstClient.
  ///
  /// In en, this message translates to:
  /// **'Add your first client to get started'**
  String get addFirstClient;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get noNotes;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deactivateClient.
  ///
  /// In en, this message translates to:
  /// **'Deactivate client'**
  String get deactivateClient;

  /// No description provided for @activateClient.
  ///
  /// In en, this message translates to:
  /// **'Activate client'**
  String get activateClient;

  /// No description provided for @preferredContact.
  ///
  /// In en, this message translates to:
  /// **'Pref: {method}'**
  String preferredContact(Object method);

  /// No description provided for @noNewNotifications.
  ///
  /// In en, this message translates to:
  /// **'No new notifications'**
  String get noNewNotifications;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get editClient;

  /// No description provided for @addClientInfo.
  ///
  /// In en, this message translates to:
  /// **'Add the client\'s information'**
  String get addClientInfo;

  /// No description provided for @modifyClientInfo.
  ///
  /// In en, this message translates to:
  /// **'Modify the client\'s information'**
  String get modifyClientInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @additionalNotes.
  ///
  /// In en, this message translates to:
  /// **'Additional notes'**
  String get additionalNotes;

  /// No description provided for @preferredContactMethod.
  ///
  /// In en, this message translates to:
  /// **'Preferred contact method'**
  String get preferredContactMethod;

  /// No description provided for @contactMethodEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactMethodEmail;

  /// No description provided for @contactMethodPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get contactMethodPhone;

  /// No description provided for @contactMethodWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get contactMethodWhatsApp;

  /// No description provided for @contactMethodSMS.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get contactMethodSMS;

  /// No description provided for @createClient.
  ///
  /// In en, this message translates to:
  /// **'Create Client'**
  String get createClient;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @confirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmDeletion;

  /// No description provided for @deleteClientConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this client?'**
  String get deleteClientConfirmation;

  /// No description provided for @clientCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Client created successfully'**
  String get clientCreatedSuccessfully;

  /// No description provided for @clientUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Client updated successfully'**
  String get clientUpdatedSuccessfully;

  /// No description provided for @clientDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Client deleted successfully'**
  String get clientDeletedSuccessfully;

  /// No description provided for @clientStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Client status updated'**
  String get clientStatusUpdated;

  /// No description provided for @errorLoadingUserData.
  ///
  /// In en, this message translates to:
  /// **'Error loading user data'**
  String get errorLoadingUserData;

  /// No description provided for @errorLoadingClients.
  ///
  /// In en, this message translates to:
  /// **'Error loading clients. Check your connection.'**
  String get errorLoadingClients;

  /// No description provided for @errorLoggingOut.
  ///
  /// In en, this message translates to:
  /// **'Error logging out.'**
  String get errorLoggingOut;

  /// No description provided for @errorSavingClient.
  ///
  /// In en, this message translates to:
  /// **'Error saving client: {error}'**
  String errorSavingClient(Object error);

  /// No description provided for @errorDeletingClient.
  ///
  /// In en, this message translates to:
  /// **'Error deleting client.'**
  String get errorDeletingClient;

  /// No description provided for @errorChangingClientStatus.
  ///
  /// In en, this message translates to:
  /// **'Error changing client status.'**
  String get errorChangingClientStatus;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'The name is required'**
  String get nameRequired;

  /// No description provided for @nameLengthError.
  ///
  /// In en, this message translates to:
  /// **'The name must be between 2 and 50 characters'**
  String get nameLengthError;

  /// No description provided for @nameFormatError.
  ///
  /// In en, this message translates to:
  /// **'The name can only contain letters and spaces'**
  String get nameFormatError;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'The phone is required'**
  String get phoneRequired;

  /// No description provided for @phoneFormatError.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone format'**
  String get phoneFormatError;

  /// No description provided for @emailFormatError.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get emailFormatError;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LinkTattoo Manager'**
  String get appTitle;

  /// No description provided for @emailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or Username'**
  String get emailOrUsername;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @emailOrUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Email or username is required'**
  String get emailOrUsernameRequired;

  /// No description provided for @invalidEmailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email or username\n(minimum 3 characters, only letters, numbers, - and _)'**
  String get invalidEmailOrUsername;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @userSignedOut.
  ///
  /// In en, this message translates to:
  /// **'User signed out'**
  String get userSignedOut;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error: {error}'**
  String authError(Object error);

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Check your email and password.'**
  String get invalidCredentials;

  /// No description provided for @invalidUsernameCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Check your username and password.'**
  String get invalidUsernameCredentials;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password for user: {username}'**
  String incorrectPassword(Object username);

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found. Check that the username is correct.'**
  String get userNotFound;

  /// No description provided for @databaseConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Database connection error. Try again.'**
  String get databaseConnectionError;

  /// No description provided for @unexpectedLoginError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected login error. Try again.'**
  String get unexpectedLoginError;

  /// No description provided for @profileVerificationError.
  ///
  /// In en, this message translates to:
  /// **'Error verifying profile. Try again.'**
  String get profileVerificationError;

  /// No description provided for @signingInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Signing in with Google...'**
  String get signingInWithGoogle;

  /// No description provided for @signInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign in cancelled'**
  String get signInCancelled;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check your internet'**
  String get connectionError;

  /// No description provided for @configurationError.
  ///
  /// In en, this message translates to:
  /// **'Configuration error. Contact administrator'**
  String get configurationError;

  /// No description provided for @authTokenError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error. Try again'**
  String get authTokenError;

  /// No description provided for @alternativeMethod.
  ///
  /// In en, this message translates to:
  /// **'Alternative method'**
  String get alternativeMethod;

  /// No description provided for @directMethodFailed.
  ///
  /// In en, this message translates to:
  /// **'The direct method failed. Do you want to try Google\'s redirect method?'**
  String get directMethodFailed;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try'**
  String get tryAgain;

  /// No description provided for @alternativeMethodError.
  ///
  /// In en, this message translates to:
  /// **'Alternative method error: {error}'**
  String alternativeMethodError(Object error);

  /// No description provided for @passwordRecoveryInDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Password recovery feature in development'**
  String get passwordRecoveryInDevelopment;

  /// No description provided for @authErrorInvalidLogin.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials. Check your email or username and password.'**
  String get authErrorInvalidLogin;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed. Check your inbox and confirm your account.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Wait a few minutes before trying again.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found. Check your credentials.'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get authErrorInvalidPassword;

  /// No description provided for @authErrorSignupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Registration is temporarily disabled.'**
  String get authErrorSignupDisabled;

  /// No description provided for @authErrorEmailRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Email limit exceeded. Wait before trying again.'**
  String get authErrorEmailRateLimit;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Authentication error: {message}'**
  String authErrorGeneric(Object message);

  /// No description provided for @unexpectedGoogleError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected Google Sign-In error'**
  String get unexpectedGoogleError;

  /// No description provided for @googleError.
  ///
  /// In en, this message translates to:
  /// **'Google Error'**
  String get googleError;

  /// No description provided for @changeAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'There might be an issue with your Google account. Would you like to try with a different account or use the alternative method?'**
  String get changeAccountMessage;

  /// No description provided for @changeAccount.
  ///
  /// In en, this message translates to:
  /// **'Change Account'**
  String get changeAccount;

  /// No description provided for @retryError.
  ///
  /// In en, this message translates to:
  /// **'Error retrying login'**
  String get retryError;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordComplexity.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one letter and one number'**
  String get passwordComplexity;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created. A verification email has been sent.'**
  String get accountCreated;

  /// No description provided for @accountCreationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create account. Please try again.'**
  String get accountCreationFailed;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Please check your internet connection.'**
  String get unexpectedError;

  /// No description provided for @userAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please try logging in.'**
  String get userAlreadyRegistered;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'The email format is invalid.'**
  String get invalidEmailFormat;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @passwordRecovery.
  ///
  /// In en, this message translates to:
  /// **'Password Recovery'**
  String get passwordRecovery;

  /// No description provided for @passwordRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get passwordRecoveryTitle;

  /// No description provided for @passwordRecoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to reset your password'**
  String get passwordRecoverySubtitle;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterEmail;

  /// No description provided for @sendRecoveryEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Recovery Email'**
  String get sendRecoveryEmail;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @emailSent.
  ///
  /// In en, this message translates to:
  /// **'Email Sent'**
  String get emailSent;

  /// No description provided for @recoveryEmailSent.
  ///
  /// In en, this message translates to:
  /// **'A recovery email has been sent to your email address. Please check your inbox.'**
  String get recoveryEmailSent;

  /// No description provided for @userNotFoundOrGoogle.
  ///
  /// In en, this message translates to:
  /// **'User not found or registered with Google'**
  String get userNotFoundOrGoogle;

  /// No description provided for @googleUserNoPassword.
  ///
  /// In en, this message translates to:
  /// **'This user is registered with Google and doesn\'t need to reset password'**
  String get googleUserNoPassword;

  /// No description provided for @verifyingUser.
  ///
  /// In en, this message translates to:
  /// **'Verifying user...'**
  String get verifyingUser;

  /// No description provided for @sendingEmail.
  ///
  /// In en, this message translates to:
  /// **'Sending email...'**
  String get sendingEmail;

  /// No description provided for @emailNotValid.
  ///
  /// In en, this message translates to:
  /// **'The email format is not valid'**
  String get emailNotValid;

  /// No description provided for @recoveryError.
  ///
  /// In en, this message translates to:
  /// **'Error sending recovery email'**
  String get recoveryError;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @recoveryLinkSent.
  ///
  /// In en, this message translates to:
  /// **'A recovery link has been sent to'**
  String get recoveryLinkSent;

  /// No description provided for @didntReceiveEmail.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the email?'**
  String get didntReceiveEmail;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get setNewPassword;

  /// No description provided for @setNewPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password below'**
  String get setNewPasswordSubtitle;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @passwordUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Updated!'**
  String get passwordUpdatedTitle;

  /// No description provided for @passwordUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been successfully updated. You will be redirected to the login page.'**
  String get passwordUpdatedMessage;

  /// No description provided for @newPasswordDifferent.
  ///
  /// In en, this message translates to:
  /// **'New password should be different from the old one'**
  String get newPasswordDifferent;

  /// No description provided for @passwordUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating password'**
  String get passwordUpdateError;

  /// No description provided for @passwordMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be less than 72 characters'**
  String get passwordMaxLength;

  /// No description provided for @passwordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one letter and one number'**
  String get passwordRequirements;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and Continue'**
  String get verifyAndContinue;

  /// No description provided for @cannotResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Cannot reset password for this user.'**
  String get cannotResetPassword;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @contactAdminError.
  ///
  /// In en, this message translates to:
  /// **'Could not update password. Contact administrator.'**
  String get contactAdminError;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @accountCreatedWeb.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email and click the confirmation link. The page will refresh automatically.'**
  String get accountCreatedWeb;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @upcomingAppointmentNotification.
  ///
  /// In en, this message translates to:
  /// **'Upcoming appointment in 30 minutes'**
  String get upcomingAppointmentNotification;

  /// No description provided for @newClientRegisteredNotification.
  ///
  /// In en, this message translates to:
  /// **'New client registered'**
  String get newClientRegisteredNotification;

  /// No description provided for @reminderNotification.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderNotification;

  /// No description provided for @checkTomorrowAppointments.
  ///
  /// In en, this message translates to:
  /// **'Check tomorrow\'s appointments'**
  String get checkTomorrowAppointments;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Cient'**
  String get client;

  /// No description provided for @userType.
  ///
  /// In en, this message translates to:
  /// **'User Type'**
  String get userType;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
