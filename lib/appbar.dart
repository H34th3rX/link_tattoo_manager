import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './l10n/app_localizations.dart';
import 'theme_provider.dart';
import '../services/notifications_service.dart';
import '../services/reminder_generator_dialog.dart';
import '../integrations/employee_service.dart';

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
  return FutureBuilder<List<NotificationItem>>(
    future: NotificationsService.getNotifications(),
    builder: (context, snapshot) {
      final notificationCount = snapshot.hasData ? snapshot.data!.length : 0;
      
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
    return FutureBuilder<List<NotificationItem>>(
      future: NotificationsService.getNotifications(),
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

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Padding(
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
                    'No hay notificaciones',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return DynamicNotificationTile(
                notification: notification,
                isDark: isDark,
                onTap: () {
                  NotificationsService.markAsRead(notification.id);
                  Navigator.pop(context); // Cerrar el bottom sheet
                  
                  // Navegar según el tipo de notificación
                  _navigateBasedOnNotificationType(context, notification.type);
                },
              );
            },
          ),
        );
      },
    );
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
class DynamicNotificationTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const Color hintColor = Colors.white70;
    
    // Determinar si se debe mostrar el botón de generar recordatorio
    final bool canGenerateReminder = notification.type == 'next_appointment' || 
                                      notification.type == 'pending_confirmation';

    return AnimatedContainer(
      duration: themeAnimationDuration,
      child: ListTile(
        onTap: onTap,
        leading: AnimatedContainer(
          duration: themeAnimationDuration,
          child: CircleAvatar(
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Icon(_getIconData(notification.icon), color: primaryColor),
          ),
        ),
        title: AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? textColor : Colors.black87,
          ),
          child: Text(notification.title),
        ),
        subtitle: AnimatedDefaultTextStyle(
          duration: themeAnimationDuration,
          style: TextStyle(
            color: isDark ? hintColor : Colors.grey[600],
          ),
          child: Text(notification.subtitle),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canGenerateReminder) ...[
              IconButton(
                icon: const Icon(Icons.share, size: 20),
                color: primaryColor,
                tooltip: 'Generar Recordatorio',
                onPressed: () => _generateReminderFromNotification(notification, context),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedDefaultTextStyle(
              duration: themeAnimationDuration,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              child: Text(notification.time),
            ),
          ],
        ),
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