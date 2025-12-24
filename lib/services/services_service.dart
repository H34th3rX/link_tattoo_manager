import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------SERVICIO PARA GESTIÓN DE SERVICIOS--------------]
class ServicesService {
  static final client = Supabase.instance.client;

  //[-------------OPERACIONES CRUD PARA SERVICIOS--------------]
  
  /// Crear un nuevo servicio
  static Future<Map<String, dynamic>> createService({
    required String employeeId,
    required String name,
    bool isActive = true,
  }) async {
    try {
      final response = await client
          .from('services')
          .insert({
            'employee_id': employeeId,
            'name': name,
            'is_active': isActive,
          })
          .select()
          .single();
      
      // Convertir fechas a local
      if (response['created_at'] != null) {
        response['created_at'] = DateTime.parse(response['created_at'])
            .toLocal()
            .toIso8601String();
      }
      if (response['updated_at'] != null) {
        response['updated_at'] = DateTime.parse(response['updated_at'])
            .toLocal()
            .toIso8601String();
      }
      
      return response;
    } catch (e) {
      throw Exception('Error al crear servicio: $e');
    }
  }

  /// Obtener todos los servicios de un empleado
  /// [onlyActive] = true: solo activos, false: solo inactivos, null: todos
  static Future<List<Map<String, dynamic>>> getServices(
    String employeeId, {
    bool? onlyActive,
  }) async {
    try {
      var query = client
          .from('services')
          .select()
          .eq('employee_id', employeeId);
      
      // Filtrar por estado si se especifica
      if (onlyActive != null) {
        query = query.eq('is_active', onlyActive);
      }
      
      final response = await query.order('name', ascending: true);
      
      final services = List<Map<String, dynamic>>.from(response);
      
      // Convertir fechas a local
      for (var service in services) {
        if (service['created_at'] != null) {
          service['created_at'] = DateTime.parse(service['created_at'])
              .toLocal()
              .toIso8601String();
        }
        if (service['updated_at'] != null) {
          service['updated_at'] = DateTime.parse(service['updated_at'])
              .toLocal()
              .toIso8601String();
        }
      }
      
      return services;
    } catch (e) {
      throw Exception('Error al obtener servicios: $e');
    }
  }

  /// Obtener un servicio específico por ID
  static Future<Map<String, dynamic>?> getServiceById(
    String serviceId,
    String employeeId,
  ) async {
    try {
      final response = await client
          .from('services')
          .select()
          .eq('id', serviceId)
          .eq('employee_id', employeeId)
          .maybeSingle();
      
      if (response != null) {
        // Convertir fechas a local
        if (response['created_at'] != null) {
          response['created_at'] = DateTime.parse(response['created_at'])
              .toLocal()
              .toIso8601String();
        }
        if (response['updated_at'] != null) {
          response['updated_at'] = DateTime.parse(response['updated_at'])
              .toLocal()
              .toIso8601String();
        }
      }
      
      return response;
    } catch (e) {
      throw Exception('Error al obtener servicio: $e');
    }
  }

  /// Actualizar un servicio existente
  static Future<Map<String, dynamic>> updateService({
    required String serviceId,
    required String employeeId,
    String? name,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (name != null) updateData['name'] = name;
      if (isActive != null) updateData['is_active'] = isActive;
      
      if (updateData.isEmpty) {
        throw Exception('No hay datos para actualizar');
      }
      
      final response = await client
          .from('services')
          .update(updateData)
          .eq('id', serviceId)
          .eq('employee_id', employeeId)
          .select()
          .single();
      
      // Convertir fechas a local
      if (response['created_at'] != null) {
        response['created_at'] = DateTime.parse(response['created_at'])
            .toLocal()
            .toIso8601String();
      }
      if (response['updated_at'] != null) {
        response['updated_at'] = DateTime.parse(response['updated_at'])
            .toLocal()
            .toIso8601String();
      }
      
      return response;
    } catch (e) {
      throw Exception('Error al actualizar servicio: $e');
    }
  }

  // ❌ ELIMINADO: deleteService() - No se pueden eliminar servicios

  /// Activar o desactivar un servicio
  static Future<Map<String, dynamic>> toggleServiceStatus({
    required String serviceId,
    required String employeeId,
    required bool newStatus,
  }) async {
    try {
      final response = await client
          .from('services')
          .update({'is_active': newStatus})
          .eq('id', serviceId)
          .eq('employee_id', employeeId)
          .select()
          .single();
      
      // Convertir fechas a local
      if (response['created_at'] != null) {
        response['created_at'] = DateTime.parse(response['created_at'])
            .toLocal()
            .toIso8601String();
      }
      if (response['updated_at'] != null) {
        response['updated_at'] = DateTime.parse(response['updated_at'])
            .toLocal()
            .toIso8601String();
      }
      
      return response;
    } catch (e) {
      throw Exception('Error al cambiar estado del servicio: $e');
    }
  }

  /// Activar un servicio (atajo)
  static Future<Map<String, dynamic>> activateService({
    required String serviceId,
    required String employeeId,
  }) async {
    return await toggleServiceStatus(
      serviceId: serviceId,
      employeeId: employeeId,
      newStatus: true,
    );
  }

  /// Desactivar un servicio (atajo)
  static Future<Map<String, dynamic>> deactivateService({
    required String serviceId,
    required String employeeId,
  }) async {
    return await toggleServiceStatus(
      serviceId: serviceId,
      employeeId: employeeId,
      newStatus: false,
    );
  }

  //[-------------FUNCIONES AUXILIARES--------------]
  
  /// Buscar servicios por nombre
  /// [onlyActive] = true: solo activos, false: solo inactivos, null: todos
  static Future<List<Map<String, dynamic>>> searchServices(
    String employeeId,
    String searchQuery, {
    bool? onlyActive,
  }) async {
    try {
      var query = client
          .from('services')
          .select()
          .eq('employee_id', employeeId)
          .ilike('name', '%$searchQuery%');
      
      // Filtrar por estado si se especifica
      if (onlyActive != null) {
        query = query.eq('is_active', onlyActive);
      }
      
      final response = await query.order('name', ascending: true);
      
      final services = List<Map<String, dynamic>>.from(response);
      
      // Convertir fechas a local
      for (var service in services) {
        if (service['created_at'] != null) {
          service['created_at'] = DateTime.parse(service['created_at'])
              .toLocal()
              .toIso8601String();
        }
        if (service['updated_at'] != null) {
          service['updated_at'] = DateTime.parse(service['updated_at'])
              .toLocal()
              .toIso8601String();
        }
      }
      
      return services;
    } catch (e) {
      throw Exception('Error al buscar servicios: $e');
    }
  }

  /// Contar servicios por estado
  static Future<Map<String, int>> getServicesCounts(String employeeId) async {
    try {
      // Obtener todos los servicios
      final allServices = await client
          .from('services')
          .select('is_active')
          .eq('employee_id', employeeId);
      
      int active = 0;
      int inactive = 0;
      
      for (var service in allServices) {
        if (service['is_active'] == true) {
          active++;
        } else {
          inactive++;
        }
      }
      
      return {
        'total': allServices.length,
        'active': active,
        'inactive': inactive,
      };
    } catch (e) {
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
      };
    }
  }

  /// Contar solo servicios activos
  static Future<int> countActiveServices(String employeeId) async {
    try {
      final response = await client
          .from('services')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('is_active', true);
      
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Contar solo servicios inactivos
  static Future<int> countInactiveServices(String employeeId) async {
    try {
      final response = await client
          .from('services')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('is_active', false);
      
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Verificar si un nombre de servicio ya existe
  /// [excludeId] útil para edición (excluir el servicio actual)
  static Future<bool> serviceNameExists(
    String employeeId,
    String name, {
    String? excludeId,
  }) async {
    try {
      var query = client
          .from('services')
          .select('id')
          .eq('employee_id', employeeId)
          .ilike('name', name);
      
      // Excluir un ID específico (útil para edición)
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      
      final response = await query;
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Obtener servicios más usados en citas (para estadísticas)
  static Future<List<Map<String, dynamic>>> getMostUsedServices(
    String employeeId, {
    int limit = 10,
    bool includeInactive = false,
  }) async {
    try {
      // Obtener citas completadas con descripción
      final appointments = await client
          .from('appointments')
          .select('description')
          .eq('employee_id', employeeId)
          .eq('status', 'completa');
      
      // Obtener servicios del empleado
      final services = await getServices(
        employeeId,
        onlyActive: includeInactive ? null : true,
      );
      
      // Contar cuántas veces se usa cada servicio
      Map<String, Map<String, dynamic>> serviceCount = {};
      
      for (var service in services) {
        final serviceId = service['id'] as String;
        final serviceName = service['name'] as String;
        int count = 0;
        
        // Contar coincidencias en citas
        for (var apt in appointments) {
          final description = apt['description'] as String? ?? '';
          if (description.toLowerCase().contains(serviceName.toLowerCase())) {
            count++;
          }
        }
        
        serviceCount[serviceId] = {
          ...service,
          'usage_count': count,
        };
      }
      
      // Convertir a lista y ordenar por uso
      final sortedServices = serviceCount.values.toList()
        ..sort((a, b) => (b['usage_count'] as int).compareTo(a['usage_count'] as int));
      
      return sortedServices.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Reactivar servicios inactivos en lote
  static Future<int> reactivateMultipleServices(
    String employeeId,
    List<String> serviceIds,
  ) async {
    try {
      int reactivatedCount = 0;
      
      for (var serviceId in serviceIds) {
        try {
          await activateService(
            serviceId: serviceId,
            employeeId: employeeId,
          );
          reactivatedCount++;
        } catch (e) {
          // Continuar con el siguiente si uno falla
          continue;
        }
      }
      
      return reactivatedCount;
    } catch (e) {
      return 0;
    }
  }

  /// Desactivar servicios activos en lote
  static Future<int> deactivateMultipleServices(
    String employeeId,
    List<String> serviceIds,
  ) async {
    try {
      int deactivatedCount = 0;
      
      for (var serviceId in serviceIds) {
        try {
          await deactivateService(
            serviceId: serviceId,
            employeeId: employeeId,
          );
          deactivatedCount++;
        } catch (e) {
          // Continuar con el siguiente si uno falla
          continue;
        }
      }
      
      return deactivatedCount;
    } catch (e) {
      return 0;
    }
  }
}