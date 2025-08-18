import 'package:supabase_flutter/supabase_flutter.dart';

//[-------------SERVICIO PARA GESTIÓN DE REPORTES--------------]
class ReportsService {
  static final client = Supabase.instance.client;

  //[-------------REPORTES FINANCIEROS--------------]
  // Obtener ingresos por período (semanal, mensual)
  static Future<Map<String, dynamic>> getFinancialReport({
    required String employeeId,
    required String period, // 'weekly', 'monthly', 'yearly'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    DateTime start, end;
    
    if (startDate != null && endDate != null) {
      start = startDate;
      end = endDate;
    } else {
      final now = DateTime.now();
      switch (period) {
        case 'weekly':
          start = now.subtract(Duration(days: now.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31);
          break;
        default:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
      }
    }

    // Consulta para obtener ingresos del período
    final response = await client
        .from('appointments')
        .select('price, deposit_paid, status, start_time')
        .eq('employee_id', employeeId)
        .gte('start_time', start.toIso8601String())
        .lte('start_time', end.toIso8601String())
        .inFilter('status', ['completa', 'confirmada']);

    double totalRevenue = 0;
    double totalDeposits = 0;
    int totalAppointments = response.length;
    int completedAppointments = 0;

    for (var appointment in response) {
      final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
      final deposit = (appointment['deposit_paid'] as num?)?.toDouble() ?? 0.0;
      
      totalRevenue += price;
      totalDeposits += deposit;
      
      if (appointment['status'] == 'completa') {
        completedAppointments++;
      }
    }

    return {
      'period': period,
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'total_revenue': totalRevenue,
      'total_deposits': totalDeposits,
      'total_appointments': totalAppointments,
      'completed_appointments': completedAppointments,
      'pending_revenue': totalRevenue - totalDeposits,
      'appointments': response,
    };
  }

  //[-------------REPORTES DE CLIENTES--------------]
  // Obtener reporte de clientes activos/inactivos
  static Future<Map<String, dynamic>> getClientsReport({
    required String employeeId,
    bool includeInactive = false,
    int minAppointments = 0,
  }) async {
    // ignore: unused_local_variable
    String statusFilter = includeInactive ? '' : '.eq.true';
    
    final response = await client
        .from('clients')
        .select('id, name, phone, email, registration_date, last_appointment_date, total_appointments, status')
        .eq('employee_id', employeeId)
        .gte('total_appointments', minAppointments);

    List<Map<String, dynamic>> clients = List<Map<String, dynamic>>.from(response);
    
    // Filtrar por status si no incluye inactivos
    if (!includeInactive) {
      clients = clients.where((client) => client['status'] == true).toList();
    }

    // Calcular estadísticas
    int activeClients = clients.where((c) => c['status'] == true).length;
    int inactiveClients = clients.where((c) => c['status'] == false).length;
    int totalAppointments = clients.fold(0, (sum, client) => sum + (client['total_appointments'] as int? ?? 0));
    
    // Clientes nuevos este mes
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    int newClientsThisMonth = clients.where((client) {
      final regDate = DateTime.tryParse(client['registration_date'] ?? '');
      return regDate != null && regDate.isAfter(monthStart);
    }).length;

    return {
      'total_clients': clients.length,
      'active_clients': activeClients,
      'inactive_clients': inactiveClients,
      'new_clients_this_month': newClientsThisMonth,
      'total_appointments_all_clients': totalAppointments,
      'average_appointments_per_client': clients.isNotEmpty ? (totalAppointments / clients.length).toStringAsFixed(1) : '0.0',
      'clients': clients,
    };
  }

  //[-------------REPORTES DE CITAS--------------]
  // Obtener reporte de citas por período y estado
  static Future<Map<String, dynamic>> getAppointmentsReport({
    required String employeeId,
    required String period, // 'weekly', 'monthly', 'yearly'
    String? status, // 'pendiente', 'confirmada', 'completa', 'cancelada', 'aplazada'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    DateTime start, end;
    
    if (startDate != null && endDate != null) {
      start = startDate;
      end = endDate;
    } else {
      final now = DateTime.now();
      switch (period) {
        case 'weekly':
          start = now.subtract(Duration(days: now.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31);
          break;
        default:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
      }
    }

    var query = client
        .from('appointments')
        .select('id, client_id, start_time, end_time, description, status, price, deposit_paid, notes, created_at')
        .eq('employee_id', employeeId)
        .gte('start_time', start.toIso8601String())
        .lte('start_time', end.toIso8601String());

    if (status != null && status != 'all') {
      query = query.eq('status', status);
    }

    final response = await query.order('start_time', ascending: false);

    // Agrupar por estado
    Map<String, int> statusCount = {
      'pendiente': 0,
      'confirmada': 0,
      'completa': 0,
      'cancelada': 0,
      'aplazada': 0,
    };

    double totalRevenue = 0;
    for (var appointment in response) {
      final appointmentStatus = appointment['status'] as String? ?? 'pendiente';
      statusCount[appointmentStatus] = (statusCount[appointmentStatus] ?? 0) + 1;
      
      if (appointmentStatus == 'completa') {
        totalRevenue += (appointment['price'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return {
      'period': period,
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'total_appointments': response.length,
      'status_breakdown': statusCount,
      'total_revenue': totalRevenue,
      'appointments': response,
    };
  }

  //[-------------REPORTES DE SERVICIOS--------------]
  // Obtener reporte de servicios más populares
  static Future<Map<String, dynamic>> getServicesReport({
    required String employeeId,
    required String period, // 'weekly', 'monthly', 'yearly'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    DateTime start, end;
    
    if (startDate != null && endDate != null) {
      start = startDate;
      end = endDate;
    } else {
      final now = DateTime.now();
      switch (period) {
        case 'weekly':
          start = now.subtract(Duration(days: now.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'yearly':
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31);
          break;
        default:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
      }
    }

    final response = await client
        .from('appointments')
        .select('description, price, status, start_time')
        .eq('employee_id', employeeId)
        .eq('status', 'completa')
        .gte('start_time', start.toIso8601String())
        .lte('start_time', end.toIso8601String());

    // Agrupar servicios por descripción
    Map<String, Map<String, dynamic>> servicesData = {};
    
    for (var appointment in response) {
      final description = appointment['description'] as String? ?? 'Servicio sin descripción';
      final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
      
      if (servicesData.containsKey(description)) {
        servicesData[description]!['count'] += 1;
        servicesData[description]!['total_revenue'] += price;
      } else {
        servicesData[description] = {
          'count': 1,
          'total_revenue': price,
          'average_price': price,
        };
      }
    }

    // Calcular precio promedio y ordenar por popularidad
    servicesData.forEach((key, value) {
      value['average_price'] = value['total_revenue'] / value['count'];
    });

    final sortedServices = servicesData.entries.toList()
      ..sort((a, b) => b.value['count'].compareTo(a.value['count']));

    return {
      'period': period,
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'total_services': response.length,
      'unique_services': servicesData.length,
      'services_breakdown': Map.fromEntries(sortedServices),
      'most_popular_service': sortedServices.isNotEmpty ? sortedServices.first.key : 'N/A',
    };
  }

  //[-------------FUNCIONES AUXILIARES--------------]
  // Obtener nombres de clientes por IDs (para reportes de citas)
  static Future<Map<String, String>> getClientNames(List<String> clientIds) async {
    if (clientIds.isEmpty) return {};
    
    final response = await client
        .from('clients')
        .select('id, name')
        .inFilter('id', clientIds);
    
    Map<String, String> clientNames = {};
    for (var client in response) {
      clientNames[client['id']] = client['name'];
    }
    return clientNames;
  }

  // Validar fechas de período personalizado
  static bool isValidDateRange(DateTime startDate, DateTime endDate) {
    return startDate.isBefore(endDate) && 
           endDate.difference(startDate).inDays <= 365; // Máximo 1 año
  }
}