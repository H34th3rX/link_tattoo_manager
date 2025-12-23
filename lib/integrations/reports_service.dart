import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
      'perdida': 0,
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

//[-------------GENERACIÓN DE PDFs--------------]
  
  /// Generar PDF para cualquier tipo de reporte
  static Future<void> generatePDF({
    required String reportType,
    required String title,
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    // Agregar página según el tipo de reporte
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

    // Mostrar diálogo de impresión/guardar
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  /// PDF de Reporte Financiero
  static pw.Page _buildFinancialPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: PdfColors.amber,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Período: ${_formatPeriodForPDF(data['period'])}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Desde: ${_formatDateForPDF(data['start_date'])} - Hasta: ${_formatDateForPDF(data['end_date'])}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Resumen financiero
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Resumen Financiero', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  _buildPDFRow('Ingresos Totales:', '\$${data['total_revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildPDFRow('Depósitos Recibidos:', '\$${data['total_deposits']?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildPDFRow('Pendiente de Cobro:', '\$${data['pending_revenue']?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildPDFRow('Total de Citas:', '${data['total_appointments'] ?? 0}'),
                  _buildPDFRow('Citas Completadas:', '${data['completed_appointments'] ?? 0}'),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Tabla de citas
            if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
              pw.Text('Detalle de Citas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Estado', isHeader: true),
                      _buildTableCell('Precio', isHeader: true),
                      _buildTableCell('Depósito', isHeader: true),
                    ],
                  ),
                  // Rows
                  ...(data['appointments'] as List).take(10).map((apt) => pw.TableRow(
                    children: [
                      _buildTableCell(_formatDateForPDF(apt['start_time'])),
                      _buildTableCell(apt['status'] ?? 'N/A'),
                      _buildTableCell('\$${apt['price']?.toStringAsFixed(2) ?? '0.00'}'),
                      _buildTableCell('\$${apt['deposit_paid']?.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generado el ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  /// PDF de Reporte de Clientes
  static pw.Page _buildClientsPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: PdfColors.amber,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('Total de clientes: ${data['total_clients'] ?? 0}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Estadísticas
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Estadísticas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  _buildPDFRow('Clientes Activos:', '${data['active_clients'] ?? 0}'),
                  _buildPDFRow('Clientes Inactivos:', '${data['inactive_clients'] ?? 0}'),
                  _buildPDFRow('Nuevos este mes:', '${data['new_clients_this_month'] ?? 0}'),
                  _buildPDFRow('Promedio de citas por cliente:', '${data['average_appointments_per_client'] ?? '0.0'}'),
                  _buildPDFRow('Total de citas (todos):', '${data['total_appointments_all_clients'] ?? 0}'),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Tabla de clientes
            if (data['clients'] != null && (data['clients'] as List).isNotEmpty) ...[
              pw.Text('Lista de Clientes', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Nombre', isHeader: true),
                      _buildTableCell('Teléfono', isHeader: true),
                      _buildTableCell('Citas', isHeader: true),
                      _buildTableCell('Estado', isHeader: true),
                    ],
                  ),
                  ...(data['clients'] as List).take(15).map((client) => pw.TableRow(
                    children: [
                      _buildTableCell(client['name'] ?? 'N/A'),
                      _buildTableCell(client['phone'] ?? 'N/A'),
                      _buildTableCell('${client['total_appointments'] ?? 0}'),
                      _buildTableCell(client['status'] == true ? 'Activo' : 'Inactivo'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generado el ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  /// PDF de Reporte de Citas
  static pw.Page _buildAppointmentsPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        final statusBreakdown = data['status_breakdown'] as Map<String, dynamic>? ?? {};
        
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: PdfColors.amber,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('Período: ${_formatPeriodForPDF(data['period'])}', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Total de citas: ${data['total_appointments'] ?? 0}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Desglose por estado
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Desglose por Estado', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  _buildPDFRow('Pendientes:', '${statusBreakdown['pendiente'] ?? 0}'),
                  _buildPDFRow('Confirmadas:', '${statusBreakdown['confirmada'] ?? 0}'),
                  _buildPDFRow('Completadas:', '${statusBreakdown['completa'] ?? 0}'),
                  _buildPDFRow('Canceladas:', '${statusBreakdown['cancelada'] ?? 0}'),
                  _buildPDFRow('Aplazadas:', '${statusBreakdown['aplazada'] ?? 0}'),
                  _buildPDFRow('Perdidas:', '${statusBreakdown['perdida'] ?? 0}'),
                  pw.Divider(),
                  _buildPDFRow('Ingresos Totales:', '\$${data['total_revenue']?.toStringAsFixed(2) ?? '0.00'}', isBold: true),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Tabla de citas
            if (data['appointments'] != null && (data['appointments'] as List).isNotEmpty) ...[
              pw.Text('Detalle de Citas', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Fecha', isHeader: true),
                      _buildTableCell('Descripción', isHeader: true),
                      _buildTableCell('Estado', isHeader: true),
                      _buildTableCell('Precio', isHeader: true),
                    ],
                  ),
                  ...(data['appointments'] as List).take(12).map((apt) => pw.TableRow(
                    children: [
                      _buildTableCell(_formatDateForPDF(apt['start_time'])),
                      _buildTableCell(apt['description'] ?? 'N/A'),
                      _buildTableCell(apt['status'] ?? 'N/A'),
                      _buildTableCell('\$${apt['price']?.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  )),
                ],
              ),
            ],
            
            pw.Spacer(),
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generado el ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  /// PDF de Reporte de Servicios
  static pw.Page _buildServicesPDF(String title, Map<String, dynamic> data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        final servicesBreakdown = data['services_breakdown'] as Map<String, dynamic>? ?? {};
        
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: PdfColors.amber,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text('Período: ${_formatPeriodForPDF(data['period'])}', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Total de servicios: ${data['total_services'] ?? 0}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Resumen
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Resumen de Servicios', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  _buildPDFRow('Servicios Únicos:', '${data['unique_services'] ?? 0}'),
                  _buildPDFRow('Total de Servicios:', '${data['total_services'] ?? 0}'),
                  _buildPDFRow('Servicio Más Popular:', data['most_popular_service'] ?? 'N/A'),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Tabla de servicios
            if (servicesBreakdown.isNotEmpty) ...[
              pw.Text('Desglose de Servicios', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _buildTableCell('Servicio', isHeader: true),
                      _buildTableCell('Cantidad', isHeader: true),
                      _buildTableCell('Ingresos', isHeader: true),
                      _buildTableCell('Promedio', isHeader: true),
                    ],
                  ),
                  ...servicesBreakdown.entries.take(15).map((entry) {
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
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generado el ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  // Funciones auxiliares para PDFs
  static pw.Widget _buildPDFRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
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

  static String _formatPeriodForPDF(String? period) {
    switch (period) {
      case 'weekly': return 'Semanal';
      case 'monthly': return 'Mensual';
      case 'yearly': return 'Anual';
      case 'custom': return 'Personalizado';
      default: return period ?? 'N/A';
    }
  }
}