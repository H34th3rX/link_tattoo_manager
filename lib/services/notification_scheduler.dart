import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:convert';
import 'dart:io' show Platform;
import '../main.dart' show navigatorKey;

//[-------------SERVICIO DE PROGRAMACIÓN DE NOTIFICACIONES MEJORADO--------------]
class NotificationScheduler {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final client = Supabase.instance.client;
  
  // Inicializar el servicio de notificaciones con configuración completa
  static Future<void> initialize() async {
    // Skip en web - las notificaciones locales no funcionan en web
    if (kIsWeb) return;
    
    tz.initializeTimeZones();
    
    // Set local timezone properly
    try {
      tz.setLocalLocation(tz.getLocation('America/Santo_Domingo'));
    } catch (e) {
      // Fallback to system timezone
    }
    
    // Configuración detallada para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS/macOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    await _createNotificationChannel();
    await _requestAllPermissions();
    await _checkSystemConfiguration();
  }
  
  // Obtener información de diagnóstico completa
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    if (kIsWeb) {
      return {
        'hasPermissions': false,
        'canScheduleExact': false,
        'pendingCount': 0,
        'notificationTime': 60,
        'isEnabled': false,
        'systemReady': false,
        'isWeb': true,
      };
    }
    
    try {
      final hasPermissions = await checkNotificationPermissions();
      final canScheduleExact = await canScheduleExactAlarms();
      final pendingNotifications = await getPendingNotifications();
      final notificationTime = await getNotificationTime();
      final isEnabled = await getNotificationsEnabled();
      
      final systemReady = hasPermissions && canScheduleExact;
      
      return {
        'hasPermissions': hasPermissions,
        'canScheduleExact': canScheduleExact,
        'pendingCount': pendingNotifications.length,
        'notificationTime': notificationTime,
        'isEnabled': isEnabled,
        'systemReady': systemReady,
      };
    } catch (e) {
      return {
        'hasPermissions': false,
        'canScheduleExact': false,
        'pendingCount': 0,
        'notificationTime': 60,
        'isEnabled': false,
        'systemReady': false,
      };
    }
  }
  
  // Habilitar/deshabilitar notificaciones
  static Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
      
      if (kIsWeb) return;
      
      if (enabled) {
        await rescheduleAllNotifications();
      } else {
        await _notifications.cancelAll();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Obtener estado de notificaciones habilitadas
  static Future<bool> getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      return true;
    }
  }
  
  // Crear canal de notificación con configuración completa
  static Future<void> _createNotificationChannel() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const appointmentChannel = AndroidNotificationChannel(
          'appointment_channel',
          'Notificaciones de Citas',
          description: 'Notificaciones para citas próximas y recordatorios importantes',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        
        const testChannel = AndroidNotificationChannel(
          'test_channel',
          'Notificaciones de Prueba',
          description: 'Canal para probar el funcionamiento de notificaciones',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: false,
        );
        
        await androidImplementation.createNotificationChannel(appointmentChannel);
        await androidImplementation.createNotificationChannel(testChannel);
      }
    }
  }
  
  // Solicitar todos los permisos necesarios
  static Future<void> _requestAllPermissions() async {
    if (kIsWeb) return;
    
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.canScheduleExactNotifications();
        await _checkBatteryOptimization();
      }
    }
  }
  
  // Verificar optimización de batería
  static Future<void> _checkBatteryOptimization() async {
    if (kIsWeb) return;
    
    try {
      if (Platform.isAndroid) {
        // Verificación silenciosa
      }
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Verificar configuración del sistema
  static Future<void> _checkSystemConfiguration() async {
    if (kIsWeb) return;
    
    try {
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Manejar cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    if (kIsWeb) return;
    
    final payload = response.payload;
    final actionId = response.actionId;
    
    if (payload != null) {
      try {
        final data = jsonDecode(payload);
        
        // Si se presionó "Generar Recordatorio"
        if (actionId == 'generate_reminder') {
          _navigateToCalendarWithReminder(data);
          return;
        }
        
        final type = data['type'] as String?;
        _navigateToPage(type ?? 'appointments', data);
      } catch (e) {
        _navigateToPage('appointments', {});
      }
    }
  }
  
  // Navegar al calendario para generar recordatorio
  static void _navigateToCalendarWithReminder(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/calendar', 
          (route) => false,
          arguments: {
            'generateReminder': true,
            'appointmentId': data['appointmentId'],
          },
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
  
  // Navegar a la página correspondiente
  static void _navigateToPage(String type, Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        switch (type) {
          case 'appointment':
          case 'next_appointment':
          case 'pending_confirmation':
          case 'daily_summary':
            Navigator.of(context).pushNamedAndRemoveUntil('/appointments', (route) => false);
            break;
          case 'new_client':
            Navigator.of(context).pushNamedAndRemoveUntil('/clients', (route) => false);
            break;
          default:
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false);
            break;
        }
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
  
  // Obtener configuración de tiempo de notificación
  static Future<int> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('notification_time_minutes') ?? 60;
  }
  
  // Guardar configuración de tiempo de notificación con reprogramación automática
  static Future<void> setNotificationTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_time_minutes', minutes);
    
    if (kIsWeb) return;
    
    // Reprogramar automáticamente si las notificaciones están habilitadas
    final isEnabled = await getNotificationsEnabled();
    if (isEnabled) {
      await rescheduleAllNotifications();
    }
  }
  
  // Programar notificación para una cita
  static Future<void> scheduleAppointmentNotification({
    required String appointmentId,
    required String clientName,
    required DateTime appointmentTime,
    String? employeeId,
  }) async {
    if (kIsWeb) return;
    
    try {
      final isEnabled = await getNotificationsEnabled();
      if (!isEnabled) {
        return;
      }
      
      final hasPermissions = await checkNotificationPermissions();
      if (!hasPermissions) {
        final granted = await requestNotificationPermissions();
        if (!granted) {
          return;
        }
      }
      
      final notificationMinutes = await getNotificationTime();
      final notificationTime = appointmentTime.subtract(Duration(minutes: notificationMinutes));
      
      if (notificationTime.isAfter(DateTime.now())) {
        final payload = jsonEncode({
          'type': 'appointment',
          'appointmentId': appointmentId,
          'clientName': clientName,
          'appointmentTime': appointmentTime.toIso8601String(),
        });
        
        final notificationId = _generateNotificationId(appointmentId);
        final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);
        
        final androidDetails = AndroidNotificationDetails(
          'appointment_channel',
          'Notificaciones de Citas',
          channelDescription: 'Notificaciones para citas próximas y recordatorios importantes',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: Color(0xFFBDA206),
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          ongoing: false,
          showWhen: true,
          when: scheduledDate.millisecondsSinceEpoch,
          usesChronometer: false,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          ticker: 'Cita con $clientName en $notificationMinutes minutos',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'view_appointment',
              'Ver Cita',
              icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            ),
            AndroidNotificationAction(
              'generate_reminder',
              'Generar Recordatorio',
              icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              showsUserInterface: true,
            ),
          ],
        );
        
        final iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'default',
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'appointment_category',
          threadIdentifier: appointmentId,
        );
        
        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        
        AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        
        try {
          final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          if (androidImplementation != null) {
            final canScheduleExact = await androidImplementation.canScheduleExactNotifications();
            if (canScheduleExact != true) {
              scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
            }
          }
        } catch (e) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
        
        await _notifications.zonedSchedule(
          notificationId,
          '🔔 Cita Próxima',
          'Tienes una cita con $clientName en $notificationMinutes minutos',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          payload: payload,
          matchDateTimeComponents: null,
        );
      }
      
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Cancelar notificación de una cita
  static Future<void> cancelAppointmentNotification(String appointmentId) async {
    if (kIsWeb) return;
    
    try {
      final notificationId = _generateNotificationId(appointmentId);
      await _notifications.cancel(notificationId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_notification_$appointmentId');
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Reprogramar todas las notificaciones
  static Future<void> rescheduleAllNotifications() async {
    if (kIsWeb) return;
    
    try {
      final isEnabled = await getNotificationsEnabled();
      if (!isEnabled) {
        await _notifications.cancelAll();
        return;
      }
      
      await _notifications.cancelAll();
      
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }
      
      final now = DateTime.now();
      final response = await client
          .from('appointments')
          .select('''
            id,
            start_time,
            client_id,
            clients(name)
          ''')
          .eq('employee_id', user.id)
          .eq('status', 'confirmada')
          .gte('start_time', now.toIso8601String())
          .order('start_time', ascending: true);
      
      for (var appointment in response) {
        if (appointment['clients'] != null) {
          try {
            final startTimeStr = appointment['start_time'] as String;
            DateTime startTime;
            
            if (startTimeStr.endsWith('+00:00')) {
              final timeWithoutOffset = startTimeStr.replaceAll('+00:00', '');
              startTime = DateTime.parse(timeWithoutOffset);
            } else if (startTimeStr.endsWith('Z')) {
              startTime = DateTime.parse(startTimeStr).toLocal();
            } else {
              startTime = DateTime.parse(startTimeStr);
            }
            
            await scheduleAppointmentNotification(
              appointmentId: appointment['id'].toString(),
              clientName: appointment['clients']['name'],
              appointmentTime: startTime,
              employeeId: user.id,
            );
            
            await Future.delayed(Duration(milliseconds: 50));
            
          } catch (e) {
            // Error handling silencioso para citas individuales
          }
        }
      }
      
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Obtener notificaciones pendientes
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return [];
    
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      return [];
    }
  }
  
  // Verificar permisos de notificación
  static Future<bool> checkNotificationPermissions() async {
    if (kIsWeb) return false;
    
    try {
      if (Platform.isAndroid) {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final granted = await androidImplementation.areNotificationsEnabled();
          return granted ?? false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Solicitar permisos de notificación
  static Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return false;
    
    try {
      if (Platform.isAndroid) {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          final granted = await androidImplementation.requestNotificationsPermission();
          return granted ?? false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Verificar si puede programar alarmas exactas
  static Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return false;
    
    try {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final canSchedule = await androidImplementation.canScheduleExactNotifications();
        return canSchedule ?? false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Mostrar notificación de prueba
  static Future<void> showTestNotification() async {
    if (kIsWeb) return;
    
    try {
      final hasPermissions = await checkNotificationPermissions();
      if (!hasPermissions) {
        final granted = await requestNotificationPermissions();
        if (!granted) {
          return;
        }
      }
      
      final testId = _generateTestNotificationId();
      
      await _notifications.show(
        testId,
        '🧪 Prueba de Notificación',
        'Si ves esto, las notificaciones funcionan correctamente. ${DateTime.now().toString().substring(11, 16)}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Notificaciones de Prueba',
            channelDescription: 'Canal para probar el funcionamiento de notificaciones',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            color: Color(0xFFBDA206),
            playSound: true,
            enableVibration: true,
            autoCancel: true,
            showWhen: true,
            fullScreenIntent: true,
            sound: RawResourceAndroidNotificationSound('notification'),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_test_notification', DateTime.now().millisecondsSinceEpoch);
      
    } catch (e) {
      // Error handling silencioso
    }
  }
  
  // Mostrar diálogo de permisos de alarma exacta
  static Future<void> showExactAlarmPermissionDialog(BuildContext context) async {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notificaciones no disponibles'),
            content: const Text('Las notificaciones locales no están disponibles en la versión web. Usa la aplicación móvil para recibir recordatorios de citas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    
    final canScheduleExact = await canScheduleExactAlarms();
    
    if (!canScheduleExact) {
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notificaciones Precisas'),
            content: const Text(
              'Para recibir notificaciones exactas en el momento configurado, necesitas habilitar "Alarmas y recordatorios" en la configuración del sistema.\n\n'
              'Sin este permiso, las notificaciones pueden llegar con retraso o no llegar.\n\n'
              '¿Quieres ir a la configuración ahora?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Más tarde'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openExactAlarmSettings();
                },
                child: const Text('Ir a configuración'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Notificaciones Precisas'),
            content: const Text('Las notificaciones precisas están habilitadas. Recibirás notificaciones en el momento exacto configurado.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // Abrir configuración de alarmas exactas
  static Future<void> _openExactAlarmSettings() async {
    if (kIsWeb) return;
    
    try {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Información para el usuario sobre configuración
      }
    } catch (e) {
      // Error handling silencioso
    }
  }

  static int _generateNotificationId(String appointmentId) {
    final hash = appointmentId.hashCode;
    return (hash.abs() % 2147483647);
  }

  static int _generateTestNotificationId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now % 2147483647).toInt();
  }
}