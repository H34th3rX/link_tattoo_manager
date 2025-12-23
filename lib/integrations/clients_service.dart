import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------SERVICIO PARA GESTIÓN DE CLIENTES Y CITAS--------------]
class ClientsService {
  static final client = Supabase.instance.client;

  //[-------------OPERACIONES CRUD PARA CLIENTES--------------]
  // Crear un nuevo cliente en la base de datos
  static Future<Map> createClient({
    required String employeeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? preferredContactMethod,
  }) async {
    final now = DateTime.now();
    
    final response = await client.from('clients').insert({
      'employee_id': employeeId,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'preferred_contact_method': preferredContactMethod,
      'registration_date': now.toIso8601String(), // Usar hora local
    }).select().single();
    return response;
  }

  // Obtener todos los clientes de un empleado, ordenados por fecha de registro
  static Future<List<Map<String, dynamic>>> getClients(String employeeId) async { 
    final response = await client
        .from('clients')
        .select()
        .eq('employee_id', employeeId)
        .order('registration_date', ascending: false);
    
    final clients = List<Map<String, dynamic>>.from(response);
    for (var client in clients) {
      if (client['registration_date'] != null) {
        final utcDate = DateTime.parse(client['registration_date']);
        client['registration_date'] = utcDate.toLocal().toIso8601String();
      }
    }
    
    return clients;
  }

  // Actualizar los datos de un cliente existente
  static Future<Map> updateClient({
    required String clientId,
    required String employeeId,
    String? name,
    String? phone,
    String? email,
    String? notes,
    String? preferredContactMethod,
  }) async {
    final response = await client
        .from('clients')
        .update({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (notes != null) 'notes': notes,
          if (preferredContactMethod != null) 'preferred_contact_method': preferredContactMethod,
        })
        .eq('id', clientId)
        .eq('employee_id', employeeId)
        .select()
        .single();
    return response;
  }

  // Eliminar un cliente de la base de datos
  static Future<void> deleteClient(String clientId, String employeeId) async {
    await client
        .from('clients')
        .delete()
        .eq('id', clientId)
        .eq('employee_id', employeeId);
  }

  // Cambiar el estado (activo/inactivo) de un cliente
  static Future<Map> toggleClientStatus({
    required String clientId,
    required String employeeId,
    required bool newStatus,
  }) async {
    final response = await client
        .from('clients')
        .update({'status': newStatus})
        .eq('id', clientId)
        .eq('employee_id', employeeId)
        .select()
        .single();
    return response;
  }

  //[-------------FUNCIONES PARA EL DASHBOARD--------------]
  // Obtener el cliente más reciente de un empleado
  static Future<Map?> getLatestClient(String employeeId) async {
    final response = await client
        .from('clients')
        .select('id, name, registration_date')
        .eq('employee_id', employeeId)
        .order('registration_date', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response != null && response['registration_date'] != null) {
      final utcDate = DateTime.parse(response['registration_date']);
      response['registration_date'] = utcDate.toLocal().toIso8601String();
    }
    
    return response;
  }

  // Obtener la cita más reciente de un empleado
  static Future<Map?> getLatestAppointment(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('id, client_id, start_time, status')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response != null && response['start_time'] != null) {
      final utcDate = DateTime.parse(response['start_time']);
      response['start_time'] = utcDate.toLocal().toIso8601String();
    }
    
    return response;
  }

  // Obtener las últimas tres citas de un empleado
  static Future<List<Map>> getLastThreeAppointments(String employeeId) async {
    final now = DateTime.now();
    
    final response = await client
        .from('appointments')
        .select('id, client_id, start_time, status')
        .eq('employee_id', employeeId)
        // Excluir citas perdidas
        .neq('status', 'perdida')
        // Excluir citas canceladas
        .neq('status', 'cancelada')
        // Solo citas futuras o de hoy
        .gte('start_time', now.toIso8601String())
        // Ordenar por fecha ascendente (próximas primero)
        .order('start_time', ascending: true)
        .limit(3);
    
    // Convertir fechas a hora local del dispositivo
    for (var appointment in response) {
      if (appointment['start_time'] != null) {
        final utcDate = DateTime.parse(appointment['start_time']);
        appointment['start_time'] = utcDate.toLocal().toIso8601String();
      }
    }
    
    return response;
  }

  // Obtener el nombre de un cliente por su ID
  static Future<String?> getClientName(String clientId) async {
    final response = await client
        .from('clients')
        .select('name')
        .eq('id', clientId)
        .maybeSingle();
    return response?['name'] as String?;
  }

  // Contar el total de clientes activos de un empleado
  static Future<int> getClientCountByEmployee(String employeeId) async {
    final response = await client
        .from('clients')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('status', true);
    return response.length;
  }
}