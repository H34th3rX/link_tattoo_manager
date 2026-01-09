import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

//[-------------SERVICIO PARA GESTIÓN DE REPORTES--------------]
class ReportsService {
  static final client = Supabase.instance.client;

  //[-------------REPORTES FINANCIEROS--------------]
  static Future<Map<String, dynamic>> getFinancialReport({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('appointments')
          .select('id, client_id, start_time, end_time, status, price, deposit_paid, service_name_snapshot, clients(name, phone, email)')
          .eq('employee_id', employeeId)
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String())
          .order('start_time', ascending: true);

      final allAppointments = List<Map<String, dynamic>>.from(response);
      
      final appointments = allAppointments.where((apt) {
        final status = apt['status'] as String;
        final deposit = (apt['deposit_paid'] as num?)?.toDouble() ?? 0.0;
        return status == 'completa' || 
               (status == 'perdida' && deposit > 0) ||
               (status == 'aplazada' && deposit > 0);
      }).toList();

      // Calcular totales
      double totalIncome = 0.0;
      double totalDeposits = 0.0;
      double totalPending = 0.0;
      int totalAppointments = appointments.length;

      // Agrupación por servicio usando SNAPSHOT
      Map<String, Map<String, dynamic>> serviceStats = {};

      // Lista de appointments con fechas formateadas
      List<Map<String, dynamic>> formattedAppointments = [];

      for (var appointment in appointments) {
        final status = appointment['status'] as String;
        final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
        final deposit = (appointment['deposit_paid'] as num?)?.toDouble() ?? 0.0;
        
        double incomeForThis;
        double pendingForThis;
        
        if (status == 'completa') {
          incomeForThis = price;
          pendingForThis = price - deposit;
        } else {
          incomeForThis = deposit;
          pendingForThis = 0.0;
        }

        totalIncome += incomeForThis;
        totalDeposits += deposit;
        totalPending += pendingForThis;

        final serviceName = appointment['service_name_snapshot'] ?? 'Sin servicio';

        if (!serviceStats.containsKey(serviceName)) {
          serviceStats[serviceName] = {
            'name': serviceName,
            'count': 0,
            'total': 0.0,
            'deposits': 0.0,
            'pending': 0.0,
          };
        }

        serviceStats[serviceName]!['count'] = 
            (serviceStats[serviceName]!['count'] as int) + 1;
        serviceStats[serviceName]!['total'] = 
            (serviceStats[serviceName]!['total'] as double) + incomeForThis;
        serviceStats[serviceName]!['deposits'] = 
            (serviceStats[serviceName]!['deposits'] as double) + deposit;
        serviceStats[serviceName]!['pending'] = 
            (serviceStats[serviceName]!['pending'] as double) + pendingForThis;

        formattedAppointments.add({
          ...appointment,
          'date': DateFormat('yyyy-MM-dd HH:mm').format(
              DateTime.parse(appointment['start_time'])),
          'formatted_date': DateFormat('yyyy-MM-dd HH:mm').format(
              DateTime.parse(appointment['start_time'])),
          'service': serviceName,
        });
      }

      // Ordenar servicios por total (mayor a menor)
      final sortedServices = serviceStats.values.toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      // ✅ ESTRUCTURA CORRECTA - reports_page busca en data['summary']
      return {
        'summary': {
          'totalIncome': totalIncome,
          'totalDeposits': totalDeposits,
          'totalPending': totalPending,
          'totalAppointments': totalAppointments,
        },
        'total_revenue': totalIncome,  // Para PDF
        'total_deposits': totalDeposits,
        'pending_revenue': totalPending,
        'total_appointments': totalAppointments,
        'completed_appointments': totalAppointments,
        'serviceBreakdown': sortedServices,
        'appointments': formattedAppointments,  // Con fechas formateadas
        'period': 'custom',
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'dateRange': {
          'start': DateFormat('yyyy-MM-dd').format(startDate),
          'end': DateFormat('yyyy-MM-dd').format(endDate),
        },
      };
    } catch (e) {
      throw Exception('Error generating financial report: $e');
    }
  }

  //[-------------REPORTES DE CLIENTES--------------]
  static Future<Map<String, dynamic>> getClientsReport({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
    String? clientId,
    bool includeInactiveClients = false,
  }) async {
    try {
      // PASO 1: Obtener TODOS los clientes del empleado
      var clientsQuery = Supabase.instance.client
          .from('clients')
          .select('id, name, phone, email, registration_date, status')
          .eq('employee_id', employeeId);
      
      if (clientId != null) {
        clientsQuery = clientsQuery.eq('id', clientId);
      }
      
      final clientsResponse = await clientsQuery;
      final allClients = List<Map<String, dynamic>>.from(clientsResponse);
      
      final filteredClients = includeInactiveClients 
          ? allClients 
          : allClients.where((client) => client['status'] == true).toList();

      // PASO 2: Obtener citas del período
      final appointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('client_id, start_time, status, price, service_name_snapshot')
          .eq('employee_id', employeeId)
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String())
          .order('start_time', ascending: true);
      
      final periodAppointments = List<Map<String, dynamic>>.from(appointmentsResponse);
      
      // PASO 3: Obtener última cita de cada cliente
      final lastAppointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('client_id, start_time, status')
          .eq('employee_id', employeeId)
          .order('start_time', ascending: false);
      
      final allAppointments = List<Map<String, dynamic>>.from(lastAppointmentsResponse);
      
      // Mapa de última cita por cliente
      Map<String, DateTime> lastAppointmentByClient = {};
      for (var apt in allAppointments) {
        final cid = apt['client_id'] as String;
        if (!lastAppointmentByClient.containsKey(cid)) {
          lastAppointmentByClient[cid] = DateTime.parse(apt['start_time']);
        }
      }
      
      // PASO 4: Construir estadísticas
      Map<String, Map<String, dynamic>> clientStats = {};
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);  // ✅ AGREGADO
      
      int activeClientsCount = 0;
      int inactiveClientsCount = 0;
      int newClientsThisMonth = 0;  // ✅ AGREGADO
      double totalRevenueAllClients = 0.0;
      int totalAppointmentsAllClients = 0;  // ✅ AGREGADO
      
      for (var client in filteredClients) {
        final cid = client['id'] as String;
        final clientName = client['name'] ?? 'Sin nombre';
        
        // ✅ CALCULAR NUEVOS ESTE MES
        final createdAt = client['registration_date'] != null 
            ? DateTime.parse(client['registration_date'] as String)
            : DateTime(2020, 1, 1);
        
        if (createdAt.isAfter(thisMonthStart)) {
          newClientsThisMonth++;
        }
        
        final isActive = client['status'] ?? true;
        final lastAppointment = lastAppointmentByClient[cid];
        
        if (isActive) {
          activeClientsCount++;
        } else {
          inactiveClientsCount++;
        }
        
        // Inicializar estadísticas
        clientStats[cid] = {
          'clientId': cid,
          'name': clientName,
          'phone': client['phone'] ?? 'N/A',
          'email': client['email'] ?? 'N/A',
          'registration_date': client['registration_date'],
          'status': isActive,  // ✅ Para PDF
          'isActive': isActive,
          'lastAppointment': lastAppointment?.toIso8601String(),
          'total_appointments': 0,  // ✅ Snake case
          'totalAppointments': 0,  // ✅ También camelCase para compatibilidad
          'completed': 0,
          'pending': 0,
          'cancelled': 0,
          'confirmed': 0,
          'postponed': 0,
          'missed': 0,
          'totalSpent': 0.0,
          'appointments': [],
        };
      }
      
      // PASO 5: Agregar estadísticas del período
      for (var appointment in periodAppointments) {
        final cid = appointment['client_id'] as String;
        
        if (!clientStats.containsKey(cid)) continue;
        
        final status = appointment['status'] as String;
        final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
        
        clientStats[cid]!['total_appointments'] = 
            (clientStats[cid]!['total_appointments'] as int) + 1;
        clientStats[cid]!['totalAppointments'] = 
            (clientStats[cid]!['totalAppointments'] as int) + 1;
        totalAppointmentsAllClients++;  // ✅ AGREGADO
        
        // Agregar detalles
        (clientStats[cid]!['appointments'] as List).add({
          'date': DateFormat('yyyy-MM-dd HH:mm').format(
              DateTime.parse(appointment['start_time'])),
          'service': appointment['service_name_snapshot'] ?? 'Sin servicio',
          'status': status,
          'price': price,
        });
        
        // Contar por estado
        switch (status) {
          case 'completa':
            clientStats[cid]!['completed'] = 
                (clientStats[cid]!['completed'] as int) + 1;
            clientStats[cid]!['totalSpent'] = 
                (clientStats[cid]!['totalSpent'] as double) + price;
            totalRevenueAllClients += price;
            break;
          case 'pendiente':
            clientStats[cid]!['pending'] = 
                (clientStats[cid]!['pending'] as int) + 1;
            break;
          case 'cancelada':
            clientStats[cid]!['cancelled'] = 
                (clientStats[cid]!['cancelled'] as int) + 1;
            break;
          case 'confirmada':
            clientStats[cid]!['confirmed'] = 
                (clientStats[cid]!['confirmed'] as int) + 1;
            break;
          case 'aplazada':
            clientStats[cid]!['postponed'] = 
                (clientStats[cid]!['postponed'] as int) + 1;
            break;
          case 'perdida':
            clientStats[cid]!['missed'] = 
                (clientStats[cid]!['missed'] as int) + 1;
            break;
        }
      }
      
      // Ordenar clientes por gasto total
      final sortedClients = clientStats.values.toList()
        ..sort((a, b) => 
            (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));
      
      // ✅ CLAVES CORRECTAS EN SNAKE_CASE
      return {
        'clients': sortedClients,
        'total_clients': allClients.length,  // ✅ Snake case
        'active_clients': activeClientsCount,  // ✅ Snake case
        'inactive_clients': inactiveClientsCount,  // ✅ Snake case
        'new_clients_this_month': newClientsThisMonth,  // ✅ AGREGADO
        'total_appointments_all_clients': totalAppointmentsAllClients,  // ✅ AGREGADO
        'average_appointments_per_client': allClients.isEmpty   // ✅ AGREGADO
            ? '0.0' 
            : (totalAppointmentsAllClients / allClients.length).toStringAsFixed(1),
        'totalRevenue': totalRevenueAllClients,
        'averageRevenuePerClient': allClients.isEmpty 
            ? 0.0 
            : totalRevenueAllClients / allClients.length,
        'dateRange': {
          'start': DateFormat('yyyy-MM-dd').format(startDate),
          'end': DateFormat('yyyy-MM-dd').format(endDate),
        },
      };
    } catch (e) {
      throw Exception('Error generating client report: $e');
    }
  }

  //[-------------REPORTES DE CITAS--------------]
  static Future<Map<String, dynamic>> getAppointmentsReport({
    required String employeeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Obtener todas las citas
      final response = await Supabase.instance.client
        .from('appointments')
          .select('*, clients(name, phone), services(name)') 
          .eq('employee_id', employeeId)
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String())
          .order('start_time', ascending: true);

      final appointments = List<Map<String, dynamic>>.from(response);

      // Estadísticas generales
      int totalAppointments = appointments.length;
      int completed = 0;
      int pending = 0;
      int cancelled = 0;
      int confirmed = 0;
      int postponed = 0;
      int missed = 0;
      double totalRevenue = 0.0;

      // Lista detallada
      List<Map<String, dynamic>> appointmentDetails = [];

      for (var appointment in appointments) {
        final status = appointment['status'] as String;
        final client = appointment['clients'];
        final service = appointment['services'];
        final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;
        final deposit = (appointment['deposit_paid'] as num?)?.toDouble() ?? 0.0;
        
        double revenueForThis;
        if (status == 'completa') {
          revenueForThis = price;
        } else if (status == 'perdida' || status == 'aplazada') {
          revenueForThis = deposit;
        } else {
          revenueForThis = 0.0;
        }
        
        switch (status) {
          case 'completa':
            completed++;
            break;
          case 'pendiente':
            pending++;
            break;
          case 'cancelada':
            cancelled++;
            break;
          case 'confirmada':
            confirmed++;
            break;
          case 'aplazada':
            postponed++;
            break;
          case 'perdida':
            missed++;
            break;
        }
        
        totalRevenue += revenueForThis;

        appointmentDetails.add({
        'date': DateFormat('yyyy-MM-dd HH:mm').format(
            DateTime.parse(appointment['start_time'])),
        'start_time': appointment['start_time'],
        'client': client?['name'] ?? 'Sin nombre',
        'phone': client?['phone'] ?? 'N/A',
        'description': service?['name'] ?? appointment['service_name_snapshot'] ?? 'Sin servicio',
        'service': service?['name'] ?? appointment['service_name_snapshot'] ?? 'Sin servicio',
        'status': status,
        'price': price,
        'deposit_paid': deposit,
        'notes': appointment['notes'] ?? '',
      });
    }

      return {
        'total_appointments': totalAppointments,
        'completed_appointments': completed,
        'total_revenue': totalRevenue,
        'status_breakdown': {
          'pendiente': pending,
          'confirmada': confirmed,
          'completa': completed,
          'cancelada': cancelled,
          'aplazada': postponed,
          'perdida': missed,
        },
        'summary': {
          'totalAppointments': totalAppointments,
          'completed': completed,
          'pending': pending,
          'cancelled': cancelled,
          'confirmed': confirmed,
          'postponed': postponed,
          'missed': missed,
          'totalRevenue': totalRevenue,
          'completionRate': totalAppointments > 0 
              ? (completed / totalAppointments * 100).toStringAsFixed(1) 
              : '0.0',
        },
        'appointments': appointmentDetails,
        'period': 'custom',
        'dateRange': {
          'start': DateFormat('yyyy-MM-dd').format(startDate),
          'end': DateFormat('yyyy-MM-dd').format(endDate),
        },
      };
    } catch (e) {
      throw Exception('Error generating appointment report: $e');
    }
  }

  //[-------------REPORTES DE SERVICIOS--------------]
 static Future<Map<String, dynamic>> getServicesReport({
  required String employeeId,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  try {
    // Obtener todas las citas con JOIN a services
    final response = await Supabase.instance.client
        .from('appointments')
        .select('*, services(name)')
        .eq('employee_id', employeeId)
        .gte('start_time', startDate.toIso8601String())
        .lte('start_time', endDate.toIso8601String())
        .order('start_time', ascending: true);

    final appointments = List<Map<String, dynamic>>.from(response);

    // Agrupar por servicio
    Map<String, Map<String, dynamic>> serviceStats = {};

    for (var appointment in appointments) {
      final service = appointment['services'];
      final serviceName = service?['name'] ?? appointment['service_name_snapshot'] ?? 'Sin servicio';
      final status = appointment['status'] as String;
      final price = (appointment['price'] as num?)?.toDouble() ?? 0.0;

      if (!serviceStats.containsKey(serviceName)) {
        serviceStats[serviceName] = {
          'name': serviceName,
          'totalAppointments': 0,
          'count': 0,  // Para PDF
          'completed': 0,
          'pending': 0,
          'cancelled': 0,
          'confirmed': 0,
          'postponed': 0,
          'missed': 0,
          'totalRevenue': 0.0,
          'total_revenue': 0.0,  // Para PDF
          'averagePrice': 0.0,
          'average_price': 0.0,  // Para PDF
        };
      }

      serviceStats[serviceName]!['totalAppointments'] = 
          (serviceStats[serviceName]!['totalAppointments'] as int) + 1;
      serviceStats[serviceName]!['count'] = 
          (serviceStats[serviceName]!['count'] as int) + 1;
      
      // Contar por estado
      switch (status) {
        case 'completa':
          serviceStats[serviceName]!['completed'] = 
              (serviceStats[serviceName]!['completed'] as int) + 1;
          serviceStats[serviceName]!['totalRevenue'] = 
              (serviceStats[serviceName]!['totalRevenue'] as double) + price;
          serviceStats[serviceName]!['total_revenue'] = 
              (serviceStats[serviceName]!['total_revenue'] as double) + price;
          break;
        case 'pendiente':
          serviceStats[serviceName]!['pending'] = 
              (serviceStats[serviceName]!['pending'] as int) + 1;
          break;
        case 'cancelada':
          serviceStats[serviceName]!['cancelled'] = 
              (serviceStats[serviceName]!['cancelled'] as int) + 1;
          break;
        case 'confirmada':
          serviceStats[serviceName]!['confirmed'] = 
              (serviceStats[serviceName]!['confirmed'] as int) + 1;
          break;
        case 'aplazada':
          serviceStats[serviceName]!['postponed'] = 
              (serviceStats[serviceName]!['postponed'] as int) + 1;
          break;
        case 'perdida':
          serviceStats[serviceName]!['missed'] = 
              (serviceStats[serviceName]!['missed'] as int) + 1;
          break;
      }
    }

    // Calcular promedios
    for (var stats in serviceStats.values) {
      final completed = stats['completed'] as int;
      if (completed > 0) {
        final avgPrice = (stats['totalRevenue'] as double) / completed;
        stats['averagePrice'] = avgPrice;
        stats['average_price'] = avgPrice;
      }
    }

    // Ordenar por total de citas
    final sortedServices = serviceStats.values.toList()
      ..sort((a, b) => 
          (b['totalAppointments'] as int).compareTo(a['totalAppointments'] as int));

    // Encontrar el más popular
    String mostPopularService = 'N/A';
    if (sortedServices.isNotEmpty) {
      mostPopularService = sortedServices.first['name'] as String;
    }

    return {
      'total_services': sortedServices.length,
      'unique_services': serviceStats.length,
      'most_popular_service': mostPopularService,
      'services': sortedServices,
      'services_breakdown': Map.fromEntries(
        sortedServices.map((service) => MapEntry(
          service['name'] as String,
          service,
        ))
      ),
      'period': 'custom',
      'dateRange': {
        'start': DateFormat('yyyy-MM-dd').format(startDate),
        'end': DateFormat('yyyy-MM-dd').format(endDate),
      },
    };
  } catch (e) {
    throw Exception('Error generating service report: $e');
  }
}

  //[-------------FUNCIONES AUXILIARES--------------]
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

  static bool isValidDateRange(DateTime startDate, DateTime endDate) {
    return startDate.isBefore(endDate) && 
           endDate.difference(startDate).inDays <= 365;
  }

//[-------------GENERACIÓN DE PDFs--------------]
  
  static Future<void> generatePDF({
    required String reportType,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    switch (reportType) {
      case 'financial':
        pdf.addPage(_buildFinancialPDF(title, data));
        break;
      case 'clients':
        pdf.addPage(_buildClientsPDF(title, data));
        break;
      case 'appointments':
        pdf.addPage(_buildAppointmentsPDF(title, data));
        break;
      case 'services':
        pdf.addPage(_buildServicesPDF(title, data));
        break;
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static pw.Page _buildFinancialPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4, bottom: 12),
                  height: 2,
                  width: 100,
                  color: PdfColors.black,
                ),
                pw.Text(
                  'Período: ${_formatPeriodForPDF(data['period'])}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Desde: ${_formatDateForPDF(data['start_date'])} - Hasta: ${_formatDateForPDF(data['end_date'])}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RESUMEN FINANCIERO',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      _buildPDFRow('Ingresos Totales:', '\$${data['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', isBold: true),
                      pw.Divider(color: PdfColors.grey300),
                      _buildPDFRow('Depósitos Recibidos:', '\$${data['total_deposits']?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildPDFRow('Pendiente de Cobro:', '\$${data['pending_revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                      pw.Divider(color: PdfColors.grey300),
                      _buildPDFRow('Total de Citas:', '${data['total_appointments'] ?? 0}'),
                      _buildPDFRow('Citas Completadas:', '${data['completed_appointments'] ?? 0}'),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
              pw.Text(
                'DETALLE DE CITAS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                      ),
                    ),
                    children: [
                      _buildTableCell('FECHA', isHeader: true),
                      _buildTableCell('ESTADO', isHeader: true),
                      _buildTableCell('PRECIO', isHeader: true),
                      _buildTableCell('DEPÓSITO', isHeader: true),
                    ],
                  ),
                  ...(data['appointments'] as List).take(12).map((apt) => pw.TableRow(
                    children: [
                      _buildTableCell(apt['formatted_date'] ?? _formatDateForPDF(apt['start_time'])),
                      _buildTableCell(_capitalizeStatus(apt['status'] ?? 'N/A')),
                      _buildTableCell('\$${apt['price']?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildTableCell('\$${apt['deposit_paid']?.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'LinkTattoo Manager',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Generado: ${_formatDateTimeForPDF(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static pw.Page _buildClientsPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4, bottom: 12),
                  height: 2,
                  width: 100,
                  color: PdfColors.black,
                ),
                pw.Text(
                  'Total de clientes: ${data['total_clients'] ?? 0}',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ESTADÍSTICAS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                  child: pw.Column(
                    children: [
                      _buildPDFRow('Clientes Activos:', '${data['active_clients'] ?? 0}', isBold: true),
                      pw.Divider(color: PdfColors.grey300),
                      _buildPDFRow('Clientes Inactivos:', '${data['inactive_clients'] ?? 0}'),
                      _buildPDFRow('Nuevos este mes:', '${data['new_clients_this_month'] ?? 0}'),
                      pw.Divider(color: PdfColors.grey300),
                      _buildPDFRow('Promedio citas/cliente:', '${data['average_appointments_per_client'] ?? '0.0'}'),
                      _buildPDFRow('Total citas (todos):', '${data['total_appointments_all_clients'] ?? 0}'),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            if (data['clients'] != null && (data['clients'] as List).isNotEmpty) ...[
              pw.Text('LISTA DE CLIENTES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5)),
                    ),
                    children: [
                      _buildTableCell('NOMBRE', isHeader: true),
                      _buildTableCell('TELÉFONO', isHeader: true),
                      _buildTableCell('CITAS', isHeader: true),
                      _buildTableCell('ESTADO', isHeader: true),
                    ],
                  ),
                  ...(data['clients'] as List).take(18).map((client) => pw.TableRow(
                    children: [
                      _buildTableCell(client['name'] ?? 'N/A'),
                      _buildTableCell(client['phone'] ?? 'N/A'),
                      _buildTableCell('${client['total_appointments'] ?? client['totalAppointments'] ?? 0}'),
                      _buildTableCell(client['status'] == true ? 'Activo' : 'Inactivo'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LinkTattoo Manager', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generado: ${_formatDateTimeForPDF(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        );
      },
    );
  }

  static pw.Page _buildAppointmentsPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        final statusBreakdown = data['status_breakdown'] as Map<String, dynamic>? ?? {};
        
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                pw.Container(margin: const pw.EdgeInsets.only(top: 4, bottom: 12), height: 2, width: 100, color: PdfColors.black),
                pw.Text('Período: ${_formatPeriodForPDF(data['period'])}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total de citas: ${data['total_appointments'] ?? 0}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DESGLOSE POR ESTADO', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                  child: pw.Column(
                    children: [
                      _buildPDFRow('Pendientes:', '${statusBreakdown['pendiente'] ?? 0}'),
                      _buildPDFRow('Confirmadas:', '${statusBreakdown['confirmada'] ?? 0}'),
                      _buildPDFRow('Completadas:', '${statusBreakdown['completa'] ?? 0}'),
                      _buildPDFRow('Canceladas:', '${statusBreakdown['cancelada'] ?? 0}'),
                      _buildPDFRow('Aplazadas:', '${statusBreakdown['aplazada'] ?? 0}'),
                      _buildPDFRow('Perdidas:', '${statusBreakdown['perdida'] ?? 0}'),
                      pw.Divider(color: PdfColors.grey400),
                      _buildPDFRow('Ingresos Totales:', '\$${data['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', isBold: true),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
              pw.Text('DETALLE DE CITAS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5))),
                    children: [
                      _buildTableCell('FECHA', isHeader: true),
                      _buildTableCell('DESCRIPCIÓN', isHeader: true),
                      _buildTableCell('ESTADO', isHeader: true),
                      _buildTableCell('PRECIO', isHeader: true),
                    ],
                  ),
                  ...(data['appointments'] as List).take(14).map((apt) => pw.TableRow(
                    children: [
                      _buildTableCell(apt['date'] ?? _formatDateForPDF(apt['start_time'])),
                      _buildTableCell(apt['description'] ?? apt['service'] ?? 'N/A'),
                      _buildTableCell(_capitalizeStatus(apt['status'] ?? 'N/A')),
                      _buildTableCell('\$${apt['price']?.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LinkTattoo Manager', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generado: ${_formatDateTimeForPDF(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        );
      },
    );
  }

  static pw.Page _buildServicesPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        final servicesBreakdown = data['services_breakdown'] as Map<String, dynamic>? ?? {};
        
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                pw.Container(margin: const pw.EdgeInsets.only(top: 4, bottom: 12), height: 2, width: 100, color: PdfColors.black),
                pw.Text('Período: ${_formatPeriodForPDF(data['period'])}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RESUMEN DE SERVICIOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1)),
                  child: pw.Column(
                    children: [
                      _buildPDFRow('Servicios Únicos:', '${data['unique_services'] ?? 0}', isBold: true),
                      pw.Divider(color: PdfColors.grey300),
                      _buildPDFRow('Servicio Más Popular:', data['most_popular_service'] ?? 'N/A'),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            
            if (servicesBreakdown.isNotEmpty) ...[
              pw.Text('DESGLOSE DE SERVICIOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.5))),
                    children: [
                      _buildTableCell('SERVICIO', isHeader: true),
                      _buildTableCell('CANTIDAD', isHeader: true),
                      _buildTableCell('INGRESOS', isHeader: true),
                      _buildTableCell('PROMEDIO', isHeader: true),
                    ],
                  ),
                  ...servicesBreakdown.entries.take(16).map((entry) {
                    final serviceData = entry.value as Map<String, dynamic>;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(entry.key),
                        _buildTableCell('${serviceData['count'] ?? 0}'),
                        _buildTableCell('\$${serviceData['total_revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                        _buildTableCell('\$${serviceData['average_price']?.toStringAsFixed(2) ?? '0.00'}'),
                      ],
                    );
                  }),
                ],
              ),
            ],
            
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LinkTattoo Manager', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generado: ${_formatDateTimeForPDF(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        );
      },
    );
  }

  static pw.Widget _buildPDFRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          letterSpacing: isHeader ? 0.5 : 0,
        ),
      ),
    );
  }

  static String _formatDateForPDF(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  static String _formatDateTimeForPDF(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String _formatPeriodForPDF(String? period) {
    switch (period) {
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'yearly': return 'Anual';
      case 'custom': return 'Personalizado';
      default: return period ?? 'N/A';
    }
  }

  static String _capitalizeStatus(String status) {
    if (status.isEmpty) return status;
    return status[0].toUpperCase() + status.substring(1);
  }
}