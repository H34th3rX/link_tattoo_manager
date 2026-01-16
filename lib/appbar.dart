import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './l10n/app_localizations.dart';
import 'theme_provider.dart';
import '../services/notifications_service.dart';
import '../services/reminder_generator_dialog.dart';
import '../integrations/employee_service.dart';

import 'package:intl/intl.dart';
//[-------------CONSTANTES GLOBALES--------------]
const Color primaryColor = Color(0xFFBDA206);
const Color textColor = Colors.white;
const Duration themeAnimationDuration = Duration(milliseconds: 300);

//[-------------APPBAR PERSONALIZADO--------------]
class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onNotificationPressed;
  final bool isWide;
  final bool showBackButton;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.onNotificationPressed,
    required this.isWide,
    this.showBackButton = false,
  });

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  String? _cachedPhotoUrl;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeProfile();
  }

  Future<void> _loadEmployeeProfile() async {
    try {
      final profile = await EmployeeService.getCurrentEmployeeProfile();
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = profile?['photo_url'] as String?;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedPhotoUrl = null;
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDark = themeProvider.isDark;

        return AnimatedContainer(
          duration: themeAnimationDuration,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : primaryColor,
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              child: Text(widget.title),
            ),
            actions: [
              _buildNotificationButton(context, isDark, localizations),
              _buildProfileButton(context, isDark, localizations),
              const SizedBox(width: 8),
            ],
            leading: widget.showBackButton
                ? AnimatedContainer(
                    duration: themeAnimationDuration,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: localizations.back,
                      color: isDark ? textColor : Colors.black87,
                    ),
                  )
                : (widget.isWide
                    ? null
                    : Builder(
                        builder: (ctx) => AnimatedContainer(
                          duration: themeAnimationDuration,
                          child: IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                            tooltip: localizations.menu,
                            color: isDark ? textColor : Colors.black87,
                          ),
                        ),
                      )),
          ),
        );
      },
    );
  }

Widget _buildNotificationButton(BuildContext context, bool isDark, AppLocalizations localizations) {
  return FutureBuilder<List<dynamic>>(
    future: Future.wait([
      NotificationsService.getNotifications(),
      _getCurrentAppointmentsCount(),
    ]),
    builder: (context, snapshot) {
      int notificationCount = 0;
      
      if (snapshot.hasData) {
        final notifications = snapshot.data![0] as List<NotificationItem>;
        final appointmentsCount = snapshot.data![1] as int;
        notificationCount = notifications.length + appointmentsCount;
      }
      
      return AnimatedContainer(
        duration: themeAnimationDuration,
        child: GestureDetector(
          onTap: () => _showNotificationsBottomSheet(context),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => _showNotificationsBottomSheet(context),
                tooltip: localizations.notifications,
                color: isDark ? textColor : Colors.black87,
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => _showNotificationsBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notificationCount > 9 ? '9+' : notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<int> _getCurrentAppointmentsCount() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final response = await Supabase.instance.client
        .from('appointments')
        .select('id, start_time, end_time')
        .eq('employee_id', user.id)
        .gte('start_time', today.toIso8601String())
        .lt('start_time', tomorrow.toIso8601String())
        .inFilter('status', ['confirmada', 'pendiente']);

    if (response.isEmpty) return 0;

    int count = 0;
    for (final appointment in response) {
      final startTime = DateTime.parse(appointment['start_time']);
      final endTime = DateTime.parse(appointment['end_time']);

      // Contar citas en curso o próximas
      if ((now.isAfter(startTime) && now.isBefore(endTime)) || now.isBefore(startTime)) {
        count++;
      }
    }

    return count;
  } catch (e) {
    return 0;
  }
}

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DynamicNotificationsBottomSheet(),
    );
  }

  Widget _buildProfileButton(BuildContext context, bool isDark, AppLocalizations localizations) {
    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/profile'),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.amber,
              width: 2,
            ),
          ),
          child: _buildProfileAvatar(),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: _isLoadingProfile
            ? Stack(
                children: [
                  _buildDefaultProfileIcon(),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : (_cachedPhotoUrl != null && _cachedPhotoUrl!.isNotEmpty
                ? Stack(
                    children: [
                      // Fondo con el ícono por defecto
                      _buildDefaultProfileIcon(),
                      // Imagen que aparece encima con fade
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: 1.0,
                        child: Image.network(
                          _cachedPhotoUrl!,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink(); // No mostrar nada si hay error
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              // Imagen completamente cargada
                              return child;
                            }
                            // Mientras carga, no mostrar nada (se verá el fondo)
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ],
                  )
                : _buildDefaultProfileIcon()),
      ),
    );
  }

  Widget _buildDefaultProfileIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.3),
            Colors.amber.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        color: Colors.grey[600],
        size: 20,
      ),
    );
  }
}

//[-------------HOJA INFERIOR DE NOTIFICACIONES DINÁMICAS--------------]
class DynamicNotificationsBottomSheet extends StatelessWidget {
  const DynamicNotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDark = themeProvider.isDark;
        const Color cardColor = Color.fromRGBO(15, 19, 21, 0.9);
        const double borderRadius = 12.0;

        return AnimatedContainer(
          duration: themeAnimationDuration,
          decoration: BoxDecoration(
            color: isDark ? cardColor : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(borderRadius)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: themeAnimationDuration,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber, // Color amarillo para el título
                ),
                child: Text(localizations.notifications),
              ),
              const SizedBox(height: 16),
              _buildDynamicNotificationsList(context, localizations, isDark),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicNotificationsList(BuildContext context, AppLocalizations localizations, bool isDark) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        NotificationsService.getNotifications(),
        _getAppointmentsCount(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Error al cargar notificaciones',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final notifications = (snapshot.data![0] as List<NotificationItem>?) ?? [];
        final appointmentsCount = snapshot.data![1] as int;

        // Construir lista de widgets
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Widget de cita en curso y próxima cita
                CurrentAppointmentNotification(isDark: isDark),
                
                // Notificaciones normales con animación
                if (notifications.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      // Índice ajustado: suma las citas en curso/próximas
                      final animationIndex = appointmentsCount + index;
                      
                      return AnimatedNotificationItem(
                        index: animationIndex,
                        child: DynamicNotificationTile(
                          notification: notification,
                          isDark: isDark,
                          onTap: () {
                            NotificationsService.markAsRead(notification.id);
                            Navigator.pop(context);
                            _navigateBasedOnNotificationType(context, notification.type);
                          },
                        ),
                      );
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay más notificaciones',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _getAppointmentsCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 0;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('appointments')
          .select('id, start_time, end_time')
          .eq('employee_id', user.id)
          .gte('start_time', today.toIso8601String())
          .lt('start_time', tomorrow.toIso8601String())
          .inFilter('status', ['confirmada', 'pendiente']);

      if (response.isEmpty) return 0;

      int count = 0;
      for (final appointment in response) {
        final startTime = DateTime.parse(appointment['start_time']);
        final endTime = DateTime.parse(appointment['end_time']);

        // Contar citas en curso o próximas
        if ((now.isAfter(startTime) && now.isBefore(endTime)) || now.isBefore(startTime)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  void _navigateBasedOnNotificationType(BuildContext context, String notificationType) {
    switch (notificationType) {
      case 'next_appointment':
      case 'pending_confirmation':
      case 'daily_summary':
        // Todas las notificaciones relacionadas con citas van a appointments
        Navigator.of(context).pushNamed('/appointments');
        break;
      case 'new_client':
        // Notificaciones de nuevos clientes van a la página de clientes
        Navigator.of(context).pushNamed('/clients');
        break;
      default:
        // Por defecto, ir al dashboard
        Navigator.of(context).pushNamed('/dashboard');
        break;
    }
  }
}

//[-------------ELEMENTO DE NOTIFICACIÓN DINÁMICO--------------]
class DynamicNotificationTile extends StatefulWidget {
  final NotificationItem notification;
  final bool isDark;
  final VoidCallback? onTap;

  const DynamicNotificationTile({
    super.key,
    required this.notification,
    required this.isDark,
    this.onTap,
  });

  @override
  State<DynamicNotificationTile> createState() => _DynamicNotificationTileState();
}

class _DynamicNotificationTileState extends State<DynamicNotificationTile> {
  bool _canShowButton = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkIfCanGenerateReminder();
  }

  Future<void> _checkIfCanGenerateReminder() async {
    // Solo verificar para tipos de notificación relevantes
    if (widget.notification.type != 'next_appointment' && 
        widget.notification.type != 'pending_confirmation') {
      setState(() {
        _canShowButton = false;
        _isChecking = false;
      });
      return;
    }

    try {
      // Extraer appointment ID del notification ID
      final parts = widget.notification.id.split('_');
      final appointmentId = parts.last;
      
      // Buscar la cita
      final user = Supabase.instance.client.auth.currentUser!;
      final response = await Supabase.instance.client
          .from('appointments')
          .select('''
            id,
            status,
            client_id,
            service_id,
            start_time
          ''')
          .eq('id', appointmentId)
          .eq('employee_id', user.id)
          .maybeSingle();
      
      if (response == null) {
        setState(() {
          _canShowButton = false;
          _isChecking = false;
        });
        return;
      }
      
      final status = response['status'] as String;
      
      if (status == 'confirmada') {
        setState(() {
          _canShowButton = true;
          _isChecking = false;
        });
        return;
      }
      
      if (status == 'pendiente') {
        setState(() {
          _canShowButton = false;
          _isChecking = false;
        });
        return;
      }
      
      // Si la cita está aplazada, verificar la nueva cita
      if (status == 'aplazada') {
        final clientId = response['client_id'] as String;
        final serviceId = response['service_id'] as String;
        final originalStartTime = response['start_time'] as String;
        
        final newAppointment = await Supabase.instance.client
            .from('appointments')
            .select('status')
            .eq('employee_id', user.id)
            .eq('client_id', clientId)
            .eq('service_id', serviceId)
            .neq('status', 'aplazada')
            .gte('start_time', originalStartTime)
            .order('start_time', ascending: true)
            .limit(1)
            .maybeSingle();
        
        // Si no hay nueva cita, mostrar botón (aún pueden crear la nueva cita)
        if (newAppointment == null) {
          setState(() {
            _canShowButton = true;
            _isChecking = false;
          });
          return;
        }
        
        // Si hay nueva cita, verificar su status
        final newStatus = newAppointment['status'] as String;
        
        // Solo permitir si la nueva cita está CONFIRMADA
        final canShow = newStatus == 'confirmada';
        setState(() {
          _canShowButton = canShow;
          _isChecking = false;
        });
        return;
      }
      
      // Para otros status (completa, cancelada, perdida), no mostrar
      setState(() {
        _canShowButton = false;
        _isChecking = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar si puede generar recordatorio: $e');
      }
      setState(() {
        _canShowButton = false;
        _isChecking = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    const Color hintColor = Colors.white70;

    return ListTile(
      onTap: widget.onTap,
      leading: CircleAvatar(
        backgroundColor: primaryColor.withValues(alpha: 0.1),
        child: Icon(_getIconData(widget.notification.icon), color: primaryColor),
      ),
      title: Text(
        widget.notification.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: widget.isDark ? textColor : Colors.black87,
        ),
      ),
      subtitle: Text(
        widget.notification.subtitle,
        style: TextStyle(
          color: widget.isDark ? hintColor : Colors.grey[600],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isChecking && _canShowButton) ...[
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              color: primaryColor,
              tooltip: 'Generar Recordatorio',
              onPressed: () => _generateReminderFromNotification(widget.notification, context),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            widget.notification.time,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReminderFromNotification(
    NotificationItem notification,
    BuildContext context,
  ) async {
    try {
      // Extraer appointment ID del notification ID
      // El ID tiene formato: "next_appointment_{appointmentId}" o "pending_{appointmentId}"
      final parts = notification.id.split('_');
      final appointmentId = parts.last;
      
      // Buscar la cita
      final user = Supabase.instance.client.auth.currentUser!;
      final response = await Supabase.instance.client
          .from('appointments')
          .select('''
            id,
            start_time,
            price,
            deposit_paid,
            notes,
            status,
            client_id,
            service_id,
            clients(name),
            services(name)
          ''')
          .eq('id', appointmentId)
          .eq('employee_id', user.id)
          .single();
      
      // Extraer datos
      final clientName = response['clients']['name'] as String;
      final serviceName = response['services']['name'] as String;
      DateTime startTime = DateTime.parse(response['start_time']);
      final price = (response['price'] as num).toDouble();
      final depositPaid = (response['deposit_paid'] as num?)?.toDouble() ?? 0.0;
      final notes = response['notes'] as String?;
      final status = response['status'] as String;
      
      // Si la cita está aplazada, buscar la nueva cita
      if (status.toLowerCase() == 'aplazada') {
        try {
          final clientId = response['client_id'] as String;
          final serviceId = response['service_id'] as String;
          
          final newAppointment = await Supabase.instance.client
              .from('appointments')
              .select('start_time')
              .eq('employee_id', user.id)
              .eq('client_id', clientId)
              .eq('service_id', serviceId)
              .neq('status', 'aplazada')
              .neq('status', 'cancelada')
              .neq('status', 'perdida')
              .gte('start_time', response['start_time'])
              .order('start_time', ascending: true)
              .limit(1)
              .maybeSingle();
          
          if (newAppointment != null) {
            startTime = DateTime.parse(newAppointment['start_time']);
          }
        } catch (e) {
          if (kDebugMode) {
            print('No se encontró nueva cita: $e');
          }
        }
      }
      
      // Mostrar diálogo
      if (context.mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ReminderGeneratorDialog(
            clientName: clientName,
            appointmentTime: startTime,
            serviceName: serviceName,
            price: price,
            depositPaid: depositPaid,
            status: status,
            notes: notes,
            isDark: isDark,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar recordatorio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'event_available':
        return Icons.event_available;
      case 'person_add':
        return Icons.person_add;
      case 'schedule':
        return Icons.schedule;
      case 'today':
        return Icons.today;
      default:
        return Icons.notifications;
    }
  }
}

// [------------- WIDGET DE CITA EN CURSO --------------]
class CurrentAppointmentNotification extends StatefulWidget {
  final bool isDark;
  
  const CurrentAppointmentNotification({
    super.key,
    required this.isDark,
  });

  @override
  State<CurrentAppointmentNotification> createState() => _CurrentAppointmentNotificationState();
}

class _CurrentAppointmentNotificationState extends State<CurrentAppointmentNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Future<Map<String, dynamic>?> _appointmentsFuture;
  
  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Memoizar el Future para evitar múltiples llamadas
    _appointmentsFuture = _getCurrentAndNextAppointments();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getCurrentAndNextAppointments() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Buscar citas de hoy
      final response = await Supabase.instance.client
          .from('appointments')
          .select('''
            id,
            start_time,
            end_time,
            status,
            clients(name),
            services(name)
          ''')
          .eq('employee_id', user.id)
          .gte('start_time', today.toIso8601String())
          .lt('start_time', tomorrow.toIso8601String())
          .inFilter('status', ['confirmada', 'pendiente'])
          .order('start_time', ascending: true);

      if (response.isEmpty) return null;

      Map<String, dynamic>? currentAppointment;

      for (final appointment in response) {
        final startTime = DateTime.parse(appointment['start_time']);
        final endTime = DateTime.parse(appointment['end_time']);

        // SOLO verificar si está EN CURSO
        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          currentAppointment = appointment;
          break; // Solo necesitamos una
        }
      }

      // Solo retornar si hay cita en curso
      if (currentAppointment != null) {
        return {'current': currentAppointment};
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener citas: $e');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        // Mostrar nada mientras carga o si hay error
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        final currentAppointment = data['current'];

        // Si no hay cita en curso, no mostrar nada
        if (currentAppointment == null) {
          return const SizedBox.shrink();
        }

        // Solo mostrar la cita EN CURSO con animación
        return AnimatedNotificationItem(
          index: 0,
          child: _buildCurrentAppointmentTile(currentAppointment),
        );
      },
    );
  }

  Widget _buildCurrentAppointmentTile(Map<String, dynamic> appointment) {
    final startTime = DateTime.parse(appointment['start_time']);
    final endTime = DateTime.parse(appointment['end_time']);
    final clientName = appointment['clients']['name'] as String;
    
    final timeFormat = DateFormat('HH:mm');
    final timeRange = '${timeFormat.format(startTime)} - ${timeFormat.format(endTime)}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Ícono girando
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.green,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Información con badge a la derecha
              Expanded(
                child: Stack(
                  children: [
                    // Contenido (nombre y hora)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? textColor : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeRange,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // Badge posicionado a la derecha - MÁS ANCHO
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // ✅ Más padding
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10), // ✅ Bordes más grandes
                        ),
                        child: const Text(
                          'EN CURSO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// [------------- WIDGET ANIMADO PARA NOTIFICACIONES --------------]
class AnimatedNotificationItem extends StatefulWidget {
  final Widget child;
  final int index;
  
  const AnimatedNotificationItem({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<AnimatedNotificationItem> createState() => _AnimatedNotificationItemState();
}

class _AnimatedNotificationItemState extends State<AnimatedNotificationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Empieza abajo
      end: Offset.zero,            // Termina en posición normal
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Delay basado en el index para efecto escalonado suave
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
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
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}