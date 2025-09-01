import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------MODELO DE NOTIFICACIÓN--------------]
class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String time;
  final String icon;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.createdAt,
  });
}

//[-------------SERVICIO DE NOTIFICACIONES--------------]
class NotificationsService {
  static final client = Supabase.instance.client;

  static Future<String?> _getCurrentEmployeeId() async {
    try {
      final user = client.auth.currentUser;
      
      if (user != null) {
        // Verificar que el usuario existe en la tabla employees
        final response = await client
            .from('employees')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null) {
          return user.id;
        }
      }
    } catch (e) {
      // Error silencioso
    }
    return null;
  }

  // Obtener todas las notificaciones dinámicas
  static Future<List<NotificationItem>> getNotifications([String? employeeId]) async {
    List<NotificationItem> notifications = [];

    try {
      final currentEmployeeId = employeeId ?? await _getCurrentEmployeeId();
      
      if (currentEmployeeId == null) {
        return [];
      }
      
      // 1. Próxima cita
      final nextAppointment = await _getNextAppointmentNotification(currentEmployeeId);
      if (nextAppointment != null) notifications.add(nextAppointment);

      // 2. Citas pendientes por confirmar
      final pendingAppointments = await _getPendingAppointmentsNotification(currentEmployeeId);
      notifications.addAll(pendingAppointments);

      // 3. Nuevos clientes (últimas 24 horas)
      final newClients = await _getNewClientsNotification(currentEmployeeId);
      notifications.addAll(newClients);

      // 4. Citas de hoy
      final todayAppointments = await _getTodayAppointmentsNotification(currentEmployeeId);
      if (todayAppointments != null) notifications.add(todayAppointments);

      // Ordenar por fecha de creación (más recientes primero)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    } catch (e) {
      return [];
    }
  }

  // Próxima cita programada
  static Future<NotificationItem?> _getNextAppointmentNotification(String employeeId) async {
    try {
      final now = DateTime.now();
      
      final response = await client
          .from('appointments')
          .select('''
            id,
            start_time,
            client_id,
            status,
            clients(name)
          ''')
          .eq('employee_id', employeeId)
          .gte('start_time', now.toIso8601String())
          .eq('status', 'confirmada')
          .order('start_time', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null && response['clients'] != null) {
        // La fecha viene de la BD como hora local pero con +00:00 agregado por Supabase
        final startTimeStr = response['start_time'] as String;
        DateTime startTime;
        
        if (startTimeStr.endsWith('+00:00')) {
          // Supabase agregó +00:00 a una hora que era local
          // Necesitamos interpretarla como hora local, no UTC
          final timeWithoutOffset = startTimeStr.replaceAll('+00:00', '');
          startTime = DateTime.parse(timeWithoutOffset);
        } else if (startTimeStr.endsWith('Z')) {
          // Es realmente UTC, convertir a local
          startTime = DateTime.parse(startTimeStr).toLocal();
        } else {
          // Ya es local sin zona horaria
          startTime = DateTime.parse(startTimeStr);
        }
        
        final clientName = response['clients']['name'];
        final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        
        return NotificationItem(
          id: 'next_appointment_${response['id']}',
          type: 'next_appointment',
          title: 'Próxima Cita',
          subtitle: '$clientName - $timeStr',
          time: _formatTime(startTime),
          icon: 'event_available',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      // Error silencioso
    }
    return null;
  }

  // Citas pendientes por confirmar
  static Future<List<NotificationItem>> _getPendingAppointmentsNotification(String employeeId) async {
    List<NotificationItem> notifications = [];
    try {
      final response = await client
          .from('appointments')
          .select('''
            id,
            start_time,
            client_id,
            clients(name)
          ''')
          .eq('employee_id', employeeId)
          .eq('status', 'pendiente')
          .order('start_time', ascending: true)
          .limit(3);

      for (var appointment in response) {
        if (appointment['clients'] != null) {
          // La fecha viene de la BD y necesitamos manejarla correctamente
          final startTimeStr = appointment['start_time'] as String;
          DateTime startTime;
          
          if (startTimeStr.endsWith('+00:00')) {
            // Es UTC con offset explícito, pero realmente es hora local guardada como UTC
            final timeWithoutOffset = startTimeStr.replaceAll('+00:00', '');
            startTime = DateTime.parse(timeWithoutOffset);
          } else if (startTimeStr.endsWith('Z')) {
            // Es UTC, convertir a local normalmente
            startTime = DateTime.parse(startTimeStr).toLocal();
          } else {
            // Ya es local
            startTime = DateTime.parse(startTimeStr);
          }
          
          final clientName = appointment['clients']['name'];
          
          notifications.add(NotificationItem(
            id: 'pending_${appointment['id']}',
            type: 'pending_confirmation',
            title: 'Cita Pendiente por Confirmar',
            subtitle: clientName,
            time: _formatTime(startTime),
            icon: 'schedule',
            createdAt: startTime,
          ));
        }
      }
    } catch (e) {
      // Error silencioso
    }
    return notifications;
  }

  // Nuevos clientes registrados (últimas 24 horas)
  static Future<List<NotificationItem>> _getNewClientsNotification(String employeeId) async {
    List<NotificationItem> notifications = [];
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      final response = await client
          .from('clients')
          .select('id, name, registration_date')
          .eq('employee_id', employeeId)
          .gte('registration_date', yesterday.toIso8601String())
          .order('registration_date', ascending: false)
          .limit(3);

      for (var client in response) {
        // La fecha viene de la BD y necesitamos manejarla correctamente  
        final registrationDateStr = client['registration_date'] as String;
        DateTime createdAt;
        
        if (registrationDateStr.endsWith('+00:00')) {
          // Es UTC con offset explícito, pero realmente es hora local guardada como UTC
          final timeWithoutOffset = registrationDateStr.replaceAll('+00:00', '');
          createdAt = DateTime.parse(timeWithoutOffset);
        } else if (registrationDateStr.endsWith('Z')) {
          // Es UTC, convertir a local normalmente
          createdAt = DateTime.parse(registrationDateStr).toLocal();
        } else {
          // Ya es local
          createdAt = DateTime.parse(registrationDateStr);
        }
        
        notifications.add(NotificationItem(
          id: 'new_client_${client['id']}',
          type: 'new_client',
          title: 'Nuevo Cliente Registrado',
          subtitle: client['name'],
          time: _formatTime(createdAt),
          icon: 'person_add',
          createdAt: createdAt,
        ));
      }
    } catch (e) {
      // Error silencioso
    }
    return notifications;
  }

  // Resumen de citas de hoy
  static Future<NotificationItem?> _getTodayAppointmentsNotification(String employeeId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfDay = today;
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final response = await client
          .from('appointments')
          .select('id, status')
          .eq('employee_id', employeeId)
          .gte('start_time', startOfDay.toIso8601String())
          .lte('start_time', endOfDay.toIso8601String());

      if (response.isNotEmpty) {
        final totalToday = response.length;
        final completed = response.where((apt) => apt['status'] == 'completa').length;
        
        if (totalToday > 0) {
          return NotificationItem(
            id: 'today_summary',
            type: 'daily_summary',
            title: 'Resumen del Día',
            subtitle: '$completed de $totalToday citas completadas',
            time: 'Hoy',
            icon: 'today',
            createdAt: now,
          );
        }
      }
    } catch (e) {
      // Error silencioso
    }
    return null;
  }

  // Formatear tiempo relativo mejorado
  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      // Es pasado - usar "hace"
      final pastDifference = now.difference(dateTime);
      
      if (pastDifference.inDays > 0) {
        return 'Hace ${pastDifference.inDays}d';
      } else if (pastDifference.inHours > 0) {
        return 'Hace ${pastDifference.inHours}h';
      } else if (pastDifference.inMinutes > 0) {
        return 'Hace ${pastDifference.inMinutes}m';
      } else {
        return 'Ahora';
      }
    } else {
      // Es futuro - usar "en"
      if (difference.inDays > 0) {
        return 'En ${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return 'En ${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return 'En ${difference.inMinutes}m';
      } else {
        return 'Ahora';
      }
    }
  }

  // Marcar notificación como leída
  static Future<void> markAsRead(String notificationId) async {
    // Implementar lógica para marcar como leída si es necesario
  }
}