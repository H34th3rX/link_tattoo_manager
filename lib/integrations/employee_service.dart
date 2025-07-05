import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------SERVICIO PARA GESTIÓN DE EMPLEADOS--------------]
class EmployeeService {
  static final client = Supabase.instance.client;

  //[-------------OPERACIONES DEL PERFIL DEL EMPLEADO--------------]
  // Obtener el perfil del empleado por su ID de usuario
  static Future<Map<String, dynamic>?> getEmployeeProfile(String userId) async {
    try {
      final response = await client
          .from('employees')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Error al obtener el perfil del empleado: $e');
    }
  }

  // Actualizar los datos del perfil del empleado
  static Future<Map<String, dynamic>> updateEmployeeProfile({
    required String employeeId,
    String? username,
    String? phone,
    String? email,
    String? specialty,
    String? notes,
  }) async {
    final response = await client
        .from('employees')
        .update({
          if (username != null) 'username': username,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (specialty != null) 'specialty': specialty,
          if (notes != null) 'notes': notes,
        })
        .eq('id', employeeId)
        .select()
        .single();
    return response;
  }

  //[-------------FUNCIONES DE MÉTRICAS Y CITAS--------------]
  // Calcular años de experiencia desde la fecha de inicio
  static int getYearsOfExperience(DateTime startDate) {
    final now = DateTime.now();
    int years = now.year - startDate.year;
    if (now.month < startDate.month ||
        (now.month == startDate.month && now.day < startDate.day)) {
      years--;
    }
    return years;
  }

  // Contar citas del empleado en el mes actual
  static Future<int> getAppointmentsThisMonth(String employeeId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final response = await client
          .from('appointments')
          .select('id')
          .eq('employee_id', employeeId)
          .gte('start_time', startOfMonth.toIso8601String())
          .lte('start_time', endOfMonth.toIso8601String());
      return response.length;
    } catch (e) {
      throw Exception('Error al obtener citas del mes: $e');
    }
  }

  // Obtener la próxima cita programada del empleado
  static Future<Map<String, dynamic>?> getNextAppointment(String employeeId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await client
          .from('appointments')
          .select('start_time, client_id, status')
          .eq('employee_id', employeeId)
          .gte('start_time', now)
          .order('start_time', ascending: true)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final clientName = await client
            .from('clients')
            .select('name')
            .eq('id', response['client_id'])
            .maybeSingle();
        response['clientName'] = clientName?['name'];
      }
      return response;
    } catch (e) {
      throw Exception('Error al obtener la próxima cita: $e');
    }
  }
}