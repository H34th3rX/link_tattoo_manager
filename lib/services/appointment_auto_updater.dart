import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_scheduler.dart';

//[-------------SERVICIO DE AUTO-ACTUALIZACIÓN DE CITAS--------------]
/// Este servicio se encarga de verificar periódicamente las citas y actualizar
/// automáticamente su estado cuando pasa su hora programada
class AppointmentAutoUpdater {
  static final client = Supabase.instance.client;
  static Timer? _timer;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Configuración del intervalo de verificación (en minutos)
  static const int _checkIntervalMinutes = 5; 
  
  // Margen de tiempo para considerar una cita como "perdida" (en minutos)
  static const int _missedMarginMinutes = 15;   
  /// Inicializar el servicio de auto-actualización
  static Future<void> initialize() async {
    try {
      // Verificar inmediatamente al iniciar
      await _checkAndUpdateAppointments();
      
      // Iniciar el timer periódico
      startPeriodicCheck();
      
      if (kDebugMode) {
        print('✅ AppointmentAutoUpdater inicializado - Verificando cada $_checkIntervalMinutes minuto(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al inicializar AppointmentAutoUpdater: $e');
      }
    }
  }
  
  /// Iniciar verificación periódica
  static void startPeriodicCheck() {
    _timer?.cancel(); // Cancelar timer anterior si existe
    
    _timer = Timer.periodic(
      Duration(minutes: _checkIntervalMinutes),
      (_) => _checkAndUpdateAppointments(),
    );
    
    if (kDebugMode) {
      print('⏰ Timer periódico iniciado - Verificación cada $_checkIntervalMinutes minuto(s)');
    }
  }
  
  /// Detener verificación periódica
  static void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
    
    if (kDebugMode) {
      print('⏸️ Timer periódico detenido');
    }
  }
  
  /// Verificar y actualizar citas que ya pasaron
  static Future<void> _checkAndUpdateAppointments() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('⚠️ No hay usuario logueado - saltando verificación');
        }
        return;
      }
      
      final now = DateTime.now().toUtc();
      final missedThreshold = now.subtract(Duration(minutes: _missedMarginMinutes));
      
      if (kDebugMode) {
        print('🔍 Verificando citas... Hora actual UTC: ${now.toIso8601String()}');
        print('📅 Umbral de citas perdidas: ${missedThreshold.toIso8601String()}');
      }
      
      final response = await client
          .from('appointments')
          .select('''
            id,
            start_time,
            end_time,
            status,
            employee_id,
            clients(
              id,
              name
            )
          ''')
          .eq('employee_id', user.id)
          .or('status.eq.confirmada,status.eq.pendiente')
          .lt('end_time', missedThreshold.toIso8601String())
          .order('start_time', ascending: true);
      
      if (response.isEmpty) {
        if (kDebugMode) {
          print('✓ No hay citas confirmadas vencidas');
        }
        return;
      }
      
      if (kDebugMode) {
        print('📋 Encontradas ${response.length} cita(s) confirmada(s)/aplazada(s) vencida(s)');
      }

      for (var appointment in response) {
        try {
          final appointmentId = appointment['id'] as String;
          final clientName = appointment['clients']['name'] as String;
          final endTimeStr = appointment['end_time'] as String;
          
          if (kDebugMode) {
            print('📌 Procesando cita: $appointmentId - $clientName - End time: $endTimeStr');
          }
          
          DateTime endTime;
          if (endTimeStr.endsWith('+00:00') || endTimeStr.endsWith('Z')) {
            endTime = DateTime.parse(endTimeStr.replaceAll('+00:00', 'Z')).toLocal();
          } else {
            endTime = DateTime.parse(endTimeStr);
          }
          
          await client
              .from('appointments')
              .update({
                'status': 'perdida',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', appointmentId)
              .eq('employee_id', user.id);
          
          if (kDebugMode) {
            print('✅ Cita actualizada a "perdida": $appointmentId - $clientName');
          }
          
          await _sendMissedAppointmentNotification(
            clientName: clientName,
            appointmentTime: endTime,
          );
          
          await NotificationScheduler.cancelAppointmentNotification(appointmentId);
          
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error al actualizar cita ${appointment['id']}: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('✓ Verificación completada');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en _checkAndUpdateAppointments: $e');
      }
    }
  }
  
  /// Enviar notificación cuando una cita se marca como perdida
  static Future<void> _sendMissedAppointmentNotification({
    required String clientName,
    required DateTime appointmentTime,
  }) async {
    // Skip en web - las notificaciones locales no funcionan en web
    if (kIsWeb) return;
    
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      
      await _notifications.show(
        notificationId,
        '⚠️ Cita Perdida',
        'La cita con $clientName (${appointmentTime.hour}:${appointmentTime.minute.toString().padLeft(2, '0')}) fue marcada como perdida',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_channel',
            'Notificaciones de Citas',
            channelDescription: 'Notificaciones para citas próximas y recordatorios importantes',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color:  Color(0xFFBDA206),
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      
      if (kDebugMode) {
        print('📱 Notificación de cita perdida enviada: $clientName');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al enviar notificación: $e');
      }
    }
  }
  
  /// Verificación manual (útil para testing o refrescar desde la UI)
  static Future<int> manualCheck() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return 0;
      
      final now = DateTime.now();
      final missedThreshold = now.subtract(Duration(minutes: _missedMarginMinutes));
      
      // Contar citas que serán actualizadas
      final response = await client
          .from('appointments')
          .select('id')
          .eq('employee_id', user.id)
          .or('status.eq.confirmada,status.eq.pendiente')
          .lt('end_time', missedThreshold.toIso8601String());
      
      final count = response.length;
      
      if (count > 0) {
        await _checkAndUpdateAppointments();
      }
      
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en verificación manual: $e');
      }
      return 0;
    }
  }
  
  /// Configurar el margen de tiempo para citas perdidas
  /// (Por defecto es 15 minutos, pero se puede ajustar según necesidad)
  static int get missedMarginMinutes => _missedMarginMinutes;
  
  /// Obtener el intervalo de verificación actual
  static int get checkIntervalMinutes => _checkIntervalMinutes;
  
  /// Verificar si el servicio está activo
  static bool get isActive => _timer != null && _timer!.isActive;
  
  /// Limpiar recursos al cerrar la app
  static void dispose() {
    stopPeriodicCheck();
    if (kDebugMode) {
      print('🗑️ AppointmentAutoUpdater limpiado');
    }
  }
}