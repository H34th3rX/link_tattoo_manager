import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_scheduler.dart';

//[-------------HELPER PARA NOTIFICACIONES DE CITAS--------------]
class AppointmentNotificationHelper {
  static final client = Supabase.instance.client;
  
  // Programar notificaciones cuando se crea una nueva cita
  static Future<void> onAppointmentCreated({
    required String appointmentId,
    required String clientName,
    required DateTime appointmentTime,
    required String status,
  }) async {
    // Solo programar notificaciones para citas confirmadas
    if (status == 'confirmada') {
      await NotificationScheduler.scheduleAppointmentNotification(
        appointmentId: appointmentId,
        clientName: clientName,
        appointmentTime: appointmentTime,
      );
    }
  }
  
  // Actualizar notificaciones cuando se modifica una cita
  static Future<void> onAppointmentUpdated({
    required String appointmentId,
    required String clientName,
    required DateTime appointmentTime,
    required String status,
    String? previousStatus,
  }) async {
    // Cancelar notificación existente
    await NotificationScheduler.cancelAppointmentNotification(appointmentId);
    
    // Programar nueva notificación si la cita está confirmada
    if (status == 'confirmada') {
      await NotificationScheduler.scheduleAppointmentNotification(
        appointmentId: appointmentId,
        clientName: clientName,
        appointmentTime: appointmentTime,
      );
    }
  }
  
  // Cancelar notificaciones cuando se elimina una cita
  static Future<void> onAppointmentDeleted(String appointmentId) async {
    await NotificationScheduler.cancelAppointmentNotification(appointmentId);
  }
  
  // Sincronizar todas las notificaciones (útil al iniciar la app)
  static Future<void> syncAllNotifications() async {
    await NotificationScheduler.rescheduleAllNotifications();
  }
}