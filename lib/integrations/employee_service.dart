import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

//[-------------SERVICIO PARA GESTIÓN DE EMPLEADOS--------------]
class EmployeeService {
  static final client = Supabase.instance.client;

  //[-------------OPERACIONES DEL PERFIL DEL EMPLEADO--------------]
  // Obtener el perfil del empleado actual (usuario autenticado)
  static Future<Map<String, dynamic>?> getCurrentEmployeeProfile() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('No hay usuario autenticado');
      }
      
      return await getEmployeeProfile(user.id);
    } catch (e) {
      throw Exception('Error al obtener el perfil del empleado actual: $e');
    }
  }

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
    String? photoUrl,
  }) async {
    final response = await client
        .from('employees')
        .update({
          if (username != null) 'username': username,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (specialty != null) 'specialty': specialty,
          if (notes != null) 'notes': notes,
          if (photoUrl != null) 'photo_url': photoUrl,
        })
        .eq('id', employeeId)
        .select()
        .single();
    return response;
  }

  //[-------------FUNCIONES DE GESTIÓN DE FOTOS--------------]
  // Subir foto del empleado a Supabase Storage
  static Future<String> uploadEmployeePhoto({
    required String employeeId,
    required Uint8List photoBytes,
    required String fileName,
  }) async {
    try {
      final String filePath = '$employeeId/$fileName';
      
      // Subir archivo a Supabase Storage
      await client.storage
          .from('employee-photos')
          .uploadBinary(filePath, photoBytes);
      
      // Obtener URL pública
      final String publicUrl = client.storage
          .from('employee-photos')
          .getPublicUrl(filePath);
      
      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir la foto: $e');
    }
  }

  // Eliminar foto anterior del empleado
  static Future<void> deleteEmployeePhoto(String photoUrl) async {
    try {
      // Extraer el path del archivo de la URL
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf('employee-photos');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await client.storage
            .from('employee-photos')
            .remove([filePath]);
      }
    } catch (e) {
      // No lanzar error si no se puede eliminar la foto anterior
      print('Advertencia: No se pudo eliminar la foto anterior: $e');
    }
  }

  // Actualizar foto del perfil del empleado
  static Future<String> updateEmployeePhoto({
    required String employeeId,
    required Uint8List photoBytes,
    required String fileName,
    String? currentPhotoUrl,
  }) async {
    try {
      // Eliminar foto anterior si existe
      if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) {
        await deleteEmployeePhoto(currentPhotoUrl);
      }
      
      // Subir nueva foto
      final String newPhotoUrl = await uploadEmployeePhoto(
        employeeId: employeeId,
        photoBytes: photoBytes,
        fileName: fileName,
      );
      
      // Actualizar URL en la base de datos
      await updateEmployeeProfile(
        employeeId: employeeId,
        photoUrl: newPhotoUrl,
      );
      
      return newPhotoUrl;
    } catch (e) {
      throw Exception('Error al actualizar la foto del empleado: $e');
    }
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