import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------SERVICIO PARA GESTIÓN DE CITAS--------------]
class AppointmentsService {
  static final client = Supabase.instance.client;

  static Future<Map> postponeAppointment({
    required String appointmentId,
    required String employeeId,
  }) async {
    final response = await client
        .from('appointments')
        .update({
          'status': 'aplazada',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', appointmentId)
        .eq('employee_id', employeeId)
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .single();
    return response;
  }

  static List<String> getAvailableStatusesForForm() {
    return ['pendiente', 'confirmada', 'completa', 'cancelada'];
  }

  //[-------------OPERACIONES CRUD PARA CITAS--------------]
  // Crear una nueva cita en la base de datos
  static Future<Map> createAppointment({
    required String clientId,
    required String employeeId,
    required DateTime startTime,
    required DateTime endTime,
    String? description,
    String status = 'pendiente',
    double? price,
    double depositPaid = 0.00,
    String? notes,
  }) async {
    final response = await client.from('appointments').insert({
      'client_id': clientId,
      'employee_id': employeeId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'description': description,
      'status': status,
      'price': price,
      'deposit_paid': depositPaid,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    }).select('''
      *,
      clients(
        id,
        name,
        phone,
        email
      )
    ''').single();
    return response;
  }

  // Obtener todas las citas de un empleado, ordenadas por fecha de inicio
  static Future<List<Map<String, dynamic>>> getAppointments(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId)
        .order('start_time', ascending: true);
    
    return List<Map<String, dynamic>>.from(response.map((appointment) {
      if (appointment['created_at'] != null) {
        appointment['created_at'] = DateTime.parse(appointment['created_at']).toLocal().toIso8601String();
      }
      if (appointment['updated_at'] != null) {
        appointment['updated_at'] = DateTime.parse(appointment['updated_at']).toLocal().toIso8601String();
      }
      return appointment;
    }));
  }

  // Obtener citas filtradas por fecha y estado
  static Future<List<Map<String, dynamic>>> getFilteredAppointments({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    var query = client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId);

    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    
    if (endDate != null) {
      query = query.lte('start_time', endDate.toIso8601String());
    }
    
    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    final response = await query.order('start_time', ascending: true);
    
    return List<Map<String, dynamic>>.from(response.map((appointment) {
      if (appointment['created_at'] != null) {
        appointment['created_at'] = DateTime.parse(appointment['created_at']).toLocal().toIso8601String();
      }
      if (appointment['updated_at'] != null) {
        appointment['updated_at'] = DateTime.parse(appointment['updated_at']).toLocal().toIso8601String();
      }
      return appointment;
    }));
  }

  // Actualizar los datos de una cita existente
  static Future<Map> updateAppointment({
    required String appointmentId,
    required String employeeId,
    String? clientId,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? status,
    double? price,
    double? depositPaid,
    String? notes,
  }) async {
    final updateData = <String, dynamic>{};  
    
    if (clientId != null) updateData['client_id'] = clientId;
    if (startTime != null) updateData['start_time'] = startTime.toIso8601String();
    if (endTime != null) updateData['end_time'] = endTime.toIso8601String();
    if (description != null) updateData['description'] = description;
    if (status != null) updateData['status'] = status;
    if (price != null) updateData['price'] = price;
    if (depositPaid != null) updateData['deposit_paid'] = depositPaid;
    if (notes != null) updateData['notes'] = notes;
    
    updateData['updated_at'] = DateTime.now().toIso8601String();

    final response = await client
        .from('appointments')
        .update(updateData)
        .eq('id', appointmentId)
        .eq('employee_id', employeeId)
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .single();
    return response;
  }

  // Eliminar una cita de la base de datos
  static Future<void> deleteAppointment(String appointmentId, String employeeId) async {
    await client
        .from('appointments')
        .delete()
        .eq('id', appointmentId)
        .eq('employee_id', employeeId);
  }

  // Cambiar el estado de una cita
  static Future<Map> updateAppointmentStatus({
    required String appointmentId,
    required String employeeId,
    required String newStatus,
  }) async {
    final response = await client
        .from('appointments')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', appointmentId)
        .eq('employee_id', employeeId)
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .single();
    return response;
  }

  //[-------------FUNCIONES PARA EL DASHBOARD Y ESTADÍSTICAS--------------]
  // Obtener la cita más reciente de un empleado
  static Future<Map?> getLatestAppointment(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('''
          id,
          client_id,
          start_time,
          status,
          clients(name)
        ''')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }

  // Obtener las próximas citas de un empleado
  static Future<List<Map>> getUpcomingAppointments(String employeeId, {int limit = 5}) async {
    final now = DateTime.now();
    final response = await client
        .from('appointments')
        .select('''
          id,
          client_id,
          start_time,
          end_time,
          status,
          description,
          clients(name)
        ''')
        .eq('employee_id', employeeId)
        .gte('start_time', now.toIso8601String())
        .order('start_time', ascending: true)
        .limit(limit);
    return response;
  }

  // Obtener citas de hoy
  static Future<List<Map>> getTodayAppointments(String employeeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final response = await client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId)
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: true);
    
    return response.map((appointment) {
      if (appointment['created_at'] != null) {
        appointment['created_at'] = DateTime.parse(appointment['created_at']).toLocal().toIso8601String();
      }
      if (appointment['updated_at'] != null) {
        appointment['updated_at'] = DateTime.parse(appointment['updated_at']).toLocal().toIso8601String();
      }
      return appointment;
    }).toList();
  }

  // Obtener citas de esta semana
  static Future<List<Map>> getWeekAppointments(String employeeId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    final response = await client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId)
        .gte('start_time', startOfWeek.toIso8601String())
        .lte('start_time', endOfWeek.toIso8601String())
        .order('start_time', ascending: true);
    
    return response.map((appointment) {
      if (appointment['created_at'] != null) {
        appointment['created_at'] = DateTime.parse(appointment['created_at']).toLocal().toIso8601String();
      }
      if (appointment['updated_at'] != null) {
        appointment['updated_at'] = DateTime.parse(appointment['updated_at']).toLocal().toIso8601String();
      }
      return appointment;
    }).toList();
  }

  // Obtener citas de este mes
  static Future<List<Map>> getMonthAppointments(String employeeId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    final response = await client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId)
        .gte('start_time', startOfMonth.toIso8601String())
        .lte('start_time', endOfMonth.toIso8601String())
        .order('start_time', ascending: true);
    
    return response.map((appointment) {
      if (appointment['created_at'] != null) {
        appointment['created_at'] = DateTime.parse(appointment['created_at']).toLocal().toIso8601String();
      }
      if (appointment['updated_at'] != null) {
        appointment['updated_at'] = DateTime.parse(appointment['updated_at']).toLocal().toIso8601String();
      }
      return appointment;
    }).toList();
  }

  // Contar el total de citas por estado
  static Future<Map<String, int>> getAppointmentCountsByStatus(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('status')
        .eq('employee_id', employeeId);
    
    final counts = <String, int>{
      'pendiente': 0,
      'confirmada': 0,
      'completa': 0,
      'cancelada': 0,
      'aplazada': 0,
    };
    
    for (final appointment in response) {
      final status = appointment['status'] as String;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    
    return counts;
  }

  // Obtener ingresos totales por período
  static Future<double> getTotalRevenue({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = client
        .from('appointments')
        .select('price')
        .eq('employee_id', employeeId)
        .eq('status', 'completa');

    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    
    if (endDate != null) {
      query = query.lte('start_time', endDate.toIso8601String());
    }

    final response = await query;
    
    double total = 0.0;
    for (final appointment in response) {
      final price = appointment['price'];
      if (price != null) {
        total += (price as num).toDouble();
      }
    }
    
    return total;
  }

  // Verificar disponibilidad de horario
  static Future<bool> isTimeSlotAvailable({
    required String employeeId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeAppointmentId,
  }) async {
    var query = client
        .from('appointments')
        .select('id, start_time, end_time')
        .eq('employee_id', employeeId)
        .neq('status', 'cancelada');

    if (excludeAppointmentId != null) {
      query = query.neq('id', excludeAppointmentId);
    }

    final response = await query;
    
    // Verificar manualmente si hay conflictos de horario
    for (final appointment in response) {
      final appointmentStart = DateTime.parse(appointment['start_time']);
      final appointmentEnd = DateTime.parse(appointment['end_time']);
      
      // Verificar si hay solapamiento
      if (startTime.isBefore(appointmentEnd) && endTime.isAfter(appointmentStart)) {
        return false; // Hay conflicto
      }
    }
    
    return true; // No hay conflictos
  }

  // Buscar citas por texto
  static Future<List<Map<String, dynamic>>> searchAppointments({
    required String employeeId,
    required String searchQuery,
  }) async {
    final response = await client
        .from('appointments')
        .select('''
          *,
          clients(
            id,
            name,
            phone,
            email
          )
        ''')
        .eq('employee_id', employeeId)
        .or('description.ilike.%$searchQuery%,notes.ilike.%$searchQuery%,clients.name.ilike.%$searchQuery%')
        .order('start_time', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Obtener el total de ingresos de citas completadas
  static Future<double> getCompletedAppointmentsRevenue(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('price')
        .eq('employee_id', employeeId)
        .eq('status', 'completa');
    
    double total = 0.0;
    for (final appointment in response) {
      final price = appointment['price'];
      if (price != null) {
        total += (price as num).toDouble();
      }
    }
    
    return total;
  }

  // Obtener el conteo total de citas confirmadas
  static Future<int> getTotalConfirmedAppointmentsCount(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('status', 'confirmada');
    
    return response.length;
  }

  // OPCIONAL: Mantener función para citas de hoy si la necesitas en otro lugar
  static Future<int> getTodayConfirmedAppointmentsCount(String employeeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final response = await client
        .from('appointments')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('status', 'confirmada')
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String());
    
    return response.length;
  }

  // CORREGIDO: Obtener la próxima cita confirmada
  static Future<Map<String, dynamic>?> getNextConfirmedAppointment(String employeeId) async {
    final now = DateTime.now();
    
    final response = await client
        .from('appointments')
        .select('''
          id,
          start_time,
          end_time,
          status,
          description,
          clients(
            id,
            name
          )
        ''')
        .eq('employee_id', employeeId)
        .eq('status', 'confirmada')
        .gte('start_time', now.toIso8601String())  // Removido .toUtc()
        .order('start_time', ascending: true)
        .limit(1);
    
    if (response.isNotEmpty) {
      return response.first;  // Removido cast innecesario
    }
    
    return null;
  }

  // NUEVO: Obtener ingresos de la semana actual de citas completadas
  static Future<double> getThisWeekCompletedRevenue(String employeeId) async {
    final now = DateTime.now();
    
    // Calcular el inicio y fin de la semana actual (lunes a domingo)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekAtMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekAtMidnight.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    
    final response = await client
        .from('appointments')
        .select('price')
        .eq('employee_id', employeeId)
        .eq('status', 'completa')  // Solo citas completadas
        .gte('start_time', startOfWeekAtMidnight.toIso8601String())
        .lte('start_time', endOfWeek.toIso8601String());
    
    double total = 0.0;
    for (final appointment in response) {
      final price = appointment['price'];
      if (price != null) {
        total += (price as num).toDouble();
      }
    }
    
    return total;
  }

  // NUEVO: Obtener datos para el gráfico semanal (últimos 7 días)
  static Future<List<Map<String, dynamic>>> getWeeklyRevenueData(String employeeId) async {
    final now = DateTime.now();
    final weeklyData = <Map<String, dynamic>>[];
    
    // Nombres de días en español para el gráfico
    final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    // Calcular el inicio de la semana actual (lunes)
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
      
      final response = await client
          .from('appointments')
          .select('price')
          .eq('employee_id', employeeId)
          .eq('status', 'completa')
          .gte('start_time', startOfDay.toIso8601String())
          .lte('start_time', endOfDay.toIso8601String());
      
      double dayTotal = 0.0;
      for (final appointment in response) {
        final price = appointment['price'];
        if (price != null) {
          dayTotal += (price as num).toDouble();
        }
      }
      
      weeklyData.add({
        'day': dayNames[i],
        'amount': dayTotal / 1000, // Convertir a miles para el gráfico
        'fullAmount': dayTotal, // Cantidad completa para referencia
      });
    }
    
    return weeklyData;
  }
}