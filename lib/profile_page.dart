import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'nav_panel.dart';
import 'theme_provider.dart';
import 'appbar.dart';
import './integrations/clients_service.dart';
import './integrations/employee_service.dart';
import 'package:intl/intl.dart'; 
import './l10n/app_localizations.dart'; // Importar el archivo generado
import 'localization_provider.dart'; // Importar el proveedor de localización

// Constantes globales para estilos y animaciones
const Color primaryColor = Color(0xFFBDA206);
const Color backgroundColor = Colors.black;
const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
const Color textColor = Colors.white;
const Color hintColor = Colors.white70;
const Color errorColor = Color(0xFFCF6679);
const Color successColor = Color(0xFF4CAF50);
const double borderRadius = 12.0;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

//[-------------PÁGINA DE PERFIL--------------]
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  // Variables para datos del perfil y estado
  String? _userName;
  Map<String, dynamic>? _employeeProfile;
  late Future<void> _loadProfileDataFuture;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loading = false;
  bool _isPopupOpen = false;
  String? _error;
  String? _successMessage;
  late AnimationController _errorAnimationController;
  late AnimationController _successAnimationController;

  // Estadísticas del empleado
  int _yearsOfExperience = 0;
  int _totalClients = 0;
  int _appointmentsThisMonth = 0;

  late Future<Map<String, dynamic>?> _nextAppointmentFuture;

  @override
  void initState() {
    super.initState();
    _nextAppointmentFuture = Future.value(null);
    _loadProfileDataFuture = _fetchProfileData();
    // Controladores para animaciones de mensajes de error y éxito
    _errorAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: themeAnimationDuration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    // Liberar recursos
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _specialtyCtrl.dispose();
    _notesCtrl.dispose();
    _errorAnimationController.dispose();
    _successAnimationController.dispose();
    super.dispose();
  }

  //[-------------CARGA DE DATOS DEL PERFIL--------------]
  // Obtiene los datos del perfil del empleado desde Supabase
  Future<void> _fetchProfileData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final profile = await EmployeeService.getEmployeeProfile(user.id);
      if (!mounted) return; // Guardar el contexto

      setState(() {
        _employeeProfile = profile;
        _userName = profile?['username'] as String? ?? user.email!.split('@')[0];
        _yearsOfExperience = profile != null && profile['start_date'] != null
            ? EmployeeService.getYearsOfExperience(DateTime.parse(profile['start_date']))
            : 0;
      });

      // Carga estadísticas dinámicas
      _totalClients = await ClientsService.getClientCountByEmployee(user.id);
      _appointmentsThisMonth = await EmployeeService.getAppointmentsThisMonth(user.id);
      _nextAppointmentFuture = EmployeeService.getNextAppointment(user.id);

      if (!mounted) return; // Guardar el contexto
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return; // Guardar el contexto
      _showError(AppLocalizations.of(context)!.errorLoadingProfile(e.toString()));
    } finally {
      if (mounted) { // Guardar el contexto
        setState(() => _loading = false);
      }
    }
  }

  // Muestra mensaje de error con animación
  void _showError(String message) {
    setState(() {
      _error = message;
      _loading = false;
    });
    _errorAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _errorAnimationController.reverse();
          setState(() => _error = null);
        }
      });
    });
  }

  // Muestra mensaje de éxito con animación
  void _showSuccess(String message) {
    setState(() => _successMessage = message);
    _successAnimationController.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _successAnimationController.reverse();
          setState(() => _successMessage = null);
        }
      });
    });
  }

  // Cierra sesión y redirige a la pantalla de login
  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return; // Guardar el contexto
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      _showError(AppLocalizations.of(context)!.errorSavingProfile(e.toString()));
    }
  }

  // Muestra hoja inferior de notificaciones
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const NotificationsBottomSheet(),
    );
  }

  // Abre el popup para editar el perfil
  void _openEditProfilePopup() {
    if (_employeeProfile != null) {
      _usernameCtrl.text = _employeeProfile!['username'] ?? '';
      _phoneCtrl.text = _employeeProfile!['phone'] ?? '';
      _emailCtrl.text = _employeeProfile!['email'] ?? '';
      _specialtyCtrl.text = _employeeProfile!['specialty'] ?? '';
      _notesCtrl.text = _employeeProfile!['notes'] ?? '';
    }
    setState(() => _isPopupOpen = true);
  }

  // Cierra el popup y reinicia el formulario
  void _closePopup() {
    setState(() => _isPopupOpen = false);
    _resetForm();
  }

  // Reinicia los campos del formulario
  void _resetForm() {
    _formKey.currentState?.reset();
    _usernameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _specialtyCtrl.clear();
    _notesCtrl.clear();
  }

  // Guarda los cambios del perfil en Supabase
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      await EmployeeService.updateEmployeeProfile(
        employeeId: user.id,
        username: _usernameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        specialty: _specialtyCtrl.text.trim().isNotEmpty ? _specialtyCtrl.text.trim() : null,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );

      if (!mounted) return; // Guardar el contexto
      _showSuccess(AppLocalizations.of(context)!.profileUpdatedSuccessfully);
      _closePopup();
      await _fetchProfileData();
    } catch (e) {
      if (!mounted) return; // Guardar el contexto
      _showError(AppLocalizations.of(context)!.errorSavingProfile(e.toString()));
    } finally {
      if (mounted) { // Guardar el contexto
        setState(() => _loading = false);
      }
    }
  }

  //[-------------CONSTRUCCIÓN DE LA INTERFAZ--------------]
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final AppLocalizations localizations = AppLocalizations.of(context)!; // Obtener localizaciones
    final bool isWide = MediaQuery.of(context).size.width >= 800;
    final user = Supabase.instance.client.auth.currentUser!;
    final bool isDark = themeProvider.isDark;

    return FutureBuilder(
      future: _loadProfileDataFuture,
      builder: (context, snapshot) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Scaffold(
              backgroundColor: isDark ? backgroundColor : Colors.grey[100],
              appBar: CustomAppBar(
                title: localizations.profilePageTitle, // Usar texto localizado
                onNotificationPressed: _showNotifications,
                isWide: isWide,
              ),
              drawer: isWide
                  ? null
                  : Drawer(
                      child: _userName != null
                          ? NavPanel(
                              user: user,
                              onLogout: _logout,
                              userName: _userName!,
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
              body: Stack(
                children: [
                  BlurredBackground(isDark: isDark),
                  isWide
                      ? Row(
                          children: [
                            SizedBox(
                              width: 280,
                              child: _userName != null
                                  ? NavPanel(
                                      user: user,
                                      onLogout: _logout,
                                      userName: _userName!,
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _buildMainContent(isDark, isWide, localizations),
                            ),
                          ],
                        )
                      : _buildMainContent(isDark, isWide, localizations),
                  if (_isPopupOpen)
                    Positioned.fill(
                      left: isWide ? 280 : 0,
                      child: ProfileEditPopup(
                        onClose: _closePopup,
                        formKey: _formKey,
                        usernameCtrl: _usernameCtrl,
                        phoneCtrl: _phoneCtrl,
                        emailCtrl: _emailCtrl,
                        specialtyCtrl: _specialtyCtrl,
                        notesCtrl: _notesCtrl,
                        loading: _loading,
                        error: _error,
                        saveProfile: _saveProfile,
                        isDark: isDark,
                        initialSpecialty: _employeeProfile?['specialty'] as String?,
                      ),
                    ),
                  if (_error != null)
                    Positioned(
                      bottom: 20,
                      left: isWide ? 296 : 16,
                      right: 16,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_errorAnimationController),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: errorColor,
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:   0.26),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_successMessage != null)
                    Positioned(
                      bottom: 20,
                      left: isWide ? 296 : 16,
                      right: 16,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(_successAnimationController),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: successColor,
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:   0.26),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Construye el contenido principal de la página
  Widget _buildMainContent(bool isDark, bool isWide, AppLocalizations localizations) {
    if (_loading && _employeeProfile == null) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }
    if (_employeeProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: isDark ? hintColor : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              localizations.noEmployeeProfileLoaded, // Usar texto localizado
              style: TextStyle(fontSize: 18, color: isDark ? hintColor : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.ensureAccountLinked, // Usar texto localizado
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? hintColor : Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchProfileData,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text(localizations.retry, style: const TextStyle(color: Colors.black)), // Usar texto localizado
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 24,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                AnimatedAppearance(
                  delay: 0,
                  child: _buildProfileHeader(isDark, localizations),
                ),
                const SizedBox(height: 24),
                AnimatedAppearance(
                  delay: 150,
                  child: _buildStatCards(isDark, localizations),
                ),
                const SizedBox(height: 32),
                AnimatedAppearance(
                  delay: 300,
                  child: Center(
                    child: SizedBox(
                      width: isWide ? 300 : double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _openEditProfilePopup,
                        icon: const Icon(Icons.edit, color: Colors.black),
                        label: Text(
                          localizations.editProfile, // Usar texto localizado
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedAppearance(
                  delay: 450,
                  child: _buildLanguageSettings(isDark, localizations), // Añadir sección de idioma
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construye el encabezado del perfil con información del empleado
  Widget _buildProfileHeader(bool isDark, AppLocalizations localizations) {
    final String initials = (_employeeProfile?['username'] as String? ?? 'UN')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join()
        .substring(0, ((_employeeProfile?['username'] as String? ?? 'UN').split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() : '').join().length > 1 ? 2 : 1));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withValues(alpha:  0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha:   0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha:   0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _employeeProfile?['username'] ?? 'Nombre de Empleado',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? textColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _employeeProfile?['specialty'] ?? localizations.selectSpecialty, // Usar texto localizado
                      style: TextStyle(
                        fontSize: 18,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_employeeProfile?['phone'] != null && _employeeProfile!['phone'].isNotEmpty)
                      _buildInfoRow(Icons.phone, _employeeProfile!['phone'], isDark),
                    if (_employeeProfile?['email'] != null && _employeeProfile!['email'].isNotEmpty)
                      _buildInfoRow(Icons.email, _employeeProfile!['email'], isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _employeeProfile?['notes'] ?? localizations.notesBiography, // Usar texto localizado
            style: TextStyle(
              fontSize: 16,
              color: isDark ? hintColor : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Construye filas de información (teléfono, email)
  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? hintColor : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? hintColor : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Construye las tarjetas de estadísticas
  Widget _buildStatCards(bool isDark, AppLocalizations localizations) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        ProfileStatCard(
          icon: Icons.emoji_events_outlined,
          value: _yearsOfExperience.toString(),
          label: localizations.years, // Usar texto localizado
          isDark: isDark,
          iconColor: Colors.blue.shade600,
          valueColor: Colors.blue.shade600,
        ),
        ProfileStatCard(
          icon: Icons.people_alt_outlined,
          value: '$_totalClients+',
          label: localizations.clients, // Usar texto localizado
          isDark: isDark,
          iconColor: Colors.green.shade600,
          valueColor: Colors.green.shade600,
        ),
        ProfileStatCard(
          icon: Icons.calendar_today_outlined,
          value: _appointmentsThisMonth.toString(),
          label: localizations.thisMonth, // Usar texto localizado
          isDark: isDark,
          iconColor: Colors.orange.shade600,
          valueColor: Colors.orange.shade600,
        ),
        FutureBuilder<Map<String, dynamic>?>(
          future: _nextAppointmentFuture,
          builder: (context, snapshot) {
            String nextAppointmentText = localizations.noAppointments; // Usar texto localizado
            Color nextAppointmentColor = isDark ? hintColor : Colors.grey[700]!;
            if (snapshot.connectionState == ConnectionState.waiting) {
              nextAppointmentText = localizations.loading; // Usar texto localizado
            } else if (snapshot.hasError) {
              nextAppointmentText = localizations.error; // Usar texto localizado
              nextAppointmentColor = errorColor;
            } else if (snapshot.hasData && snapshot.data != null) {
              final appointment = snapshot.data!;
              final startTime = DateTime.parse(appointment['start_time']).toLocal();
              nextAppointmentText = DateFormat('HH:mm').format(startTime);
              nextAppointmentColor = Colors.purple.shade600;
            }
            return ProfileStatCard(
              icon: Icons.schedule_outlined,
              value: nextAppointmentText,
              label: localizations.nextAppointment, // Usar texto localizado
              isDark: isDark,
              iconColor: Colors.purple.shade600,
              valueColor: nextAppointmentColor,
            );
          },
        ),
      ],
    );
  }

  // Nuevo widget para la configuración de idioma
  Widget _buildLanguageSettings(bool isDark, AppLocalizations localizations) {
    final localizationProvider = Provider.of<LocalizationProvider>(context);
    String currentPreference = localizationProvider.languagePreference;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withValues(alpha:  0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.languageSettings, // Usar texto localizado
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? textColor : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: currentPreference,
            hint: Text(localizations.selectLanguage, style: TextStyle(color: isDark ? hintColor : Colors.grey[600])),
            items: [
              DropdownMenuItem(
                value: 'system',
                child: Text(localizations.systemDefault, style: TextStyle(color: isDark ? primaryColor : Colors.black87)),
              ),
              DropdownMenuItem(
                value: 'en',
                child: Text(localizations.english, style: TextStyle(color: isDark ? primaryColor : Colors.black87)),
              ),
              DropdownMenuItem(
                value: 'es',
                child: Text(localizations.spanish, style: TextStyle(color: isDark ? primaryColor : Colors.black87)),
              ),
            ],
            onChanged: (value) async {
              if (value != null) {
                await localizationProvider.setLanguagePreference(value);
                if (!mounted) return; // Guardar el contexto
                _showSuccess(localizations.languagePreferenceSaved); // Mostrar mensaje de éxito
              }
            },
            decoration: InputDecoration(
              labelText: localizations.selectLanguage, // Usar texto localizado
              labelStyle: TextStyle(color: isDark ? hintColor : Colors.grey[600], fontSize: 14),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha:   0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.language, color: primaryColor, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: isDark ? Colors.grey[800]?.withValues(alpha:   0.5) : Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            dropdownColor: isDark ? Colors.grey[800] : Colors.white,
            style: TextStyle(color: isDark ? primaryColor : Colors.black87),
          ),
        ],
      ),
    );
  }
}

//[-------------TARJETA DE ESTADÍSTICAS--------------]
class ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final Color iconColor;
  final Color valueColor;

  const ProfileStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withValues(alpha:  0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 36,
            color: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? hintColor : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

//[-------------POPUP DE EDICIÓN DE PERFIL--------------]
class ProfileEditPopup extends StatefulWidget {
  final VoidCallback onClose;
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController specialtyCtrl;
  final TextEditingController notesCtrl;
  final bool loading;
  final String? error;
  final Future<void> Function() saveProfile;
  final bool isDark;
  final String? initialSpecialty;

  const ProfileEditPopup({
    super.key,
    required this.onClose,
    required this.formKey,
    required this.usernameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.specialtyCtrl,
    required this.notesCtrl,
    required this.loading,
    required this.error,
    required this.saveProfile,
    required this.isDark,
    this.initialSpecialty,
  });

  @override
  State<ProfileEditPopup> createState() => _ProfileEditPopupState();
}

class _ProfileEditPopupState extends State<ProfileEditPopup> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  String? _selectedSpecialty;
  bool _isCustomSpecialty = false;
  final List<String> _specialties = ['Tradicional', 'Realismo', 'Acuarela', 'Minimalista', 'Neotradicional', 'Otro'];

  @override
  void initState() {
    super.initState();
    // Configura animaciones para el popup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    // Inicializa la especialidad según el valor inicial
    if (widget.initialSpecialty != null && widget.initialSpecialty!.isNotEmpty) {
      if (_specialties.contains(widget.initialSpecialty)) {
        _selectedSpecialty = widget.initialSpecialty;
        _isCustomSpecialty = false;
      } else {
        _selectedSpecialty = 'Otro';
        _isCustomSpecialty = true;
        widget.specialtyCtrl.text = widget.initialSpecialty!;
      }
    } else {
      _selectedSpecialty = null;
      _isCustomSpecialty = false;
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Cierra el popup con animación
  void _closeWithAnimation() async {
    await _animationController.reverse();
    widget.onClose();
  }

  // Validaciones para los campos del formulario
  String? _validateUsername(String? value) {
    final localizations = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return localizations.username;
    if (value.length < 3 || value.length > 50) {
      return 'El nombre de usuario debe tener entre 3 y 50 caracteres'; // No localizado
    }
    return null;
  }

  String? _validatePhone(String? value) {
    // final localizations = AppLocalizations.of(context)!; // No se usa
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^\+?[\d\s\-()]{7,15}$').hasMatch(value)) {
      return 'Formato de teléfono no válido'; // No localizado
    }
    return null;
  }

  String? _validateEmail(String? value) {
    // final localizations = AppLocalizations.of(context)!; // No se usa
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value)) {
      return 'Formato de email no válido'; // No localizado
    }
    return null;
  }

  // Maneja el guardado del formulario
  Future<void> _handleSave() async {
    if (!widget.formKey.currentState!.validate()) {
      debugPrint('Validation failed. Not saving.');
      return;
    }

    if (_isCustomSpecialty) {
      // specialtyCtrl ya contiene el valor personalizado
    } else {
      widget.specialtyCtrl.text = _selectedSpecialty ?? '';
    }

    await widget.saveProfile();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha:   0.5 * _opacityAnimation.value),
          child: Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    constraints: const BoxConstraints(maxWidth: 550),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:   0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: widget.formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(widget.isDark, localizations),
                              const SizedBox(height: 28),
                              _buildFormFields(widget.isDark, localizations),
                              const SizedBox(height: 24),
                              if (widget.error != null) _buildErrorMessage(),
                              _buildActionButtons(widget.isDark, localizations),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Construye el encabezado del popup
  Widget _buildHeader(bool isDark, AppLocalizations localizations) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor,
                primaryColor.withValues(alpha:  0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.edit,
            color: Colors.black,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.editProfile, // Usar texto localizado
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? primaryColor : Colors.black87,
                ),
              ),
              Text(
                'Actualiza tu información personal y profesional', // No localizado
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? hintColor : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _closeWithAnimation,
            color: isDark ? textColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  // Construye los campos del formulario
  Widget _buildFormFields(bool isDark, AppLocalizations localizations) {
    return Column(
      children: [
        _buildAnimatedTextField(
          controller: widget.usernameCtrl,
          label: localizations.username, // Usar texto localizado
          icon: Icons.person_outline,
          validator: _validateUsername,
          isDark: isDark,
          isRequired: true,
          delay: 0,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),
        _buildSpecialtyField(isDark, localizations),
        const SizedBox(height: 20),
        _buildAnimatedTextField(
          controller: widget.phoneCtrl,
          label: localizations.phone, // Usar texto localizado
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
          isDark: isDark,
          delay: 100,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),
        _buildAnimatedTextField(
          controller: widget.emailCtrl,
          label: localizations.email, // Usar texto localizado
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
          isDark: isDark,
          delay: 150,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),
        _buildAnimatedTextField(
          controller: widget.notesCtrl,
          label: localizations.notesBiography, // Usar texto localizado
          icon: Icons.note_outlined,
          maxLines: 3,
          isDark: isDark,
          delay: 200,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ],
    );
  }

  // Construye el campo de especialidad con dropdown
  Widget _buildSpecialtyField(bool isDark, AppLocalizations localizations) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 450),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedSpecialty,
                  hint: Text(localizations.selectSpecialty, style: TextStyle(color: isDark ? hintColor : Colors.grey[600])), // Usar texto localizado
                  items: _specialties.map((String specialty) {
                    return DropdownMenuItem<String>(
                      value: specialty,
                      child: Text(specialty, style: TextStyle(color: isDark ? primaryColor : Colors.black87)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSpecialty = value;
                      _isCustomSpecialty = value == 'Otro';
                      if (!_isCustomSpecialty) widget.specialtyCtrl.clear();
                    });
                  },
                  validator: (value) => value == null ? localizations.selectSpecialty : null, // Usar texto localizado
                  decoration: InputDecoration(
                    labelText: '${localizations.specialty} *', // Usar texto localizado
                    labelStyle: TextStyle(color: isDark ? hintColor : Colors.grey[600], fontSize: 14),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha:   0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.work_outline, color: primaryColor, size: 20),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: errorColor),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: errorColor, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800]?.withValues(alpha:   0.5) : Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                  style: TextStyle(color: isDark ? primaryColor : Colors.black87),
                ),
                if (_isCustomSpecialty) ...[
                  const SizedBox(height: 20),
                  _buildAnimatedTextField(
                    controller: widget.specialtyCtrl,
                    label: localizations.customSpecialty, // Usar texto localizado
                    icon: Icons.edit,
                    isDark: isDark,
                    validator: (value) => value == null || value.isEmpty ? 'Ingresa una especialidad personalizada' : null, // No localizado
                    delay: 250,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Construye campos de texto animados
  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = false,
    int delay = 0,
    AutovalidateMode? autovalidateMode,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: validator,
              style: TextStyle(
                color: isDark ? primaryColor : Colors.black87,
                fontSize: 16,
              ),
              autovalidateMode: autovalidateMode,
              decoration: InputDecoration(
                labelText: isRequired ? '$label *' : label,
                labelStyle: TextStyle(
                  color: isDark ? hintColor : Colors.grey[600],
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha:   0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: errorColor),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: errorColor, width: 2),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800]?.withValues(alpha:   0.5) : Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        );
      },
    );
  }

  // Construye el mensaje de error
  Widget _buildErrorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            errorColor.withValues(alpha:  0.1),
            errorColor.withValues(alpha:  0.05),
          ],
        ),
        border: Border.all(color: errorColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: errorColor.withValues(alpha:   0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: errorColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.error!,
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construye los botones de acción del popup
  Widget _buildActionButtons(bool isDark, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: widget.loading ? null : _closeWithAnimation,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? primaryColor : Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    localizations.cancel, // Usar texto localizado
                    style: TextStyle(
                      color: isDark ? primaryColor : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha:  0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha:   0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.loading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.save,
                          color: Colors.black,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.saveChanges, // Usar texto localizado
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

//[-------------ANIMACIÓN DE APARICIÓN--------------]
class AnimatedAppearance extends StatefulWidget {
  final Widget child;
  final int delay;

  const AnimatedAppearance({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<AnimatedAppearance> createState() => _AnimatedAppearanceState();
}

class _AnimatedAppearanceState extends State<AnimatedAppearance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Configura animaciones de opacidad y deslizamiento
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

//[-------------FONDO DIFUMINADO--------------]
class BlurredBackground extends StatelessWidget {
  final bool isDark;

  const BlurredBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/logo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: themeAnimationDuration,
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.7)
                : Colors.white.withValues(alpha:  0.85),
          ),
        ),
      ),
    );
  }
}

//[-------------HOJA INFERIOR DE NOTIFICACIONES--------------]
class NotificationsBottomSheet extends StatelessWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Usar color del tema
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Center(
        child: Text(
          localizations.notifications, // Usar texto localizado
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), // Usar color del tema
        ),
      ),
    );
  }
}
