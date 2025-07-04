import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsService {
  static final client = Supabase.instance.client;

  // --- CRUD para Clientes ---

  // Crear un nuevo cliente
  static Future<Map> createClient({
    required String employeeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? preferredContactMethod,
  }) async {
    final response = await client.from('clients').insert({
      'employee_id': employeeId,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'preferred_contact_method': preferredContactMethod,
    }).select().single();
    return response;
  }

  // Obtener todos los clientes de un empleado
  static Future<List<Map<String, dynamic>>> getClients(String employeeId) async { // Changed return type
    final response = await client
        .from('clients')
        .select()
        .eq('employee_id', employeeId)
        .order('registration_date', ascending: false);
    return List<Map<String, dynamic>>.from(response); // Ensure correct type
  }

  // Actualizar un cliente existente
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

  // Eliminar un cliente
  static Future<void> deleteClient(String clientId, String employeeId) async {
    await client
        .from('clients')
        .delete()
        .eq('id', clientId)
        .eq('employee_id', employeeId);
  }

// Cambiar el estado de un cliente (activar/desactivar)
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
//--------------------------------------------------------------------------------------//
  // --- Funciones para el Dashboard ---

  // Obtener el último cliente registrado
  static Future<Map?> getLatestClient(String employeeId) async {
    final response = await client
        .from('clients')
        .select('id, name, registration_date')
        .eq('employee_id', employeeId)
        .order('registration_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }

  // Obtener la última cita registrada
  static Future<Map?> getLatestAppointment(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('id, client_id, start_time, status')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }

  // Obtener las últimas 3 citas
  static Future<List<Map>> getLastThreeAppointments(String employeeId) async {
    final response = await client
        .from('appointments')
        .select('id, client_id, start_time, status')
        .eq('employee_id', employeeId)
        .order('start_time', ascending: false)
        .limit(3);
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

  // Obtener el total de clientes por empleado con status = true
  static Future<int> getClientCountByEmployee(String employeeId) async {
    final response = await client
        .from('clients')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('status', true);
    return response.length;
  }
}