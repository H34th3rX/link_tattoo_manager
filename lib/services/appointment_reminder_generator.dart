import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

//[-------------GENERADOR DE RECORDATORIOS DE CITAS--------------]
class AppointmentReminderGenerator {
  // Colores base
  static final PdfColor backgroundColor = PdfColor.fromHex('#000000');
  static final PdfColor textColor = PdfColor.fromHex('#FFFFFF');
  
  // Colores para citas CONFIRMADAS (amarillo/dorado)
  static final PdfColor confirmedPrimaryColor = PdfColor.fromHex('#BDA206');
  static final PdfColor confirmedAccentColor = PdfColor.fromHex('#FFD700');
  
  // Colores para citas APLAZADAS (morado)
  static final PdfColor postponedPrimaryColor = PdfColor.fromHex('#9C27B0');
  static final PdfColor postponedAccentColor = PdfColor.fromHex('#BA68C8');
  
  /// Generar recordatorio visual de cita
  static Future<File> generateReminder({
    required String clientName,
    required DateTime appointmentTime,
    required String serviceName,
    required double price,
    required double depositPaid,
    required String status, // ← NUEVO: 'confirmada' o 'aplazada'
    String? notes,
  }) async {
    final pdf = pw.Document();
    
    // Determinar colores según el status
    final bool isPostponed = status.toLowerCase() == 'aplazada';
    final PdfColor primaryColor = isPostponed ? postponedPrimaryColor : confirmedPrimaryColor;
    final PdfColor accentColor = isPostponed ? postponedAccentColor : confirmedAccentColor;
    
    // Determinar textos según el status
    final String titleText = isPostponed ? 'CITA APLAZADA' : 'RECORDATORIO DE CITA';
    final String messageText = isPostponed
        ? 'Tu cita ha sido aplazada para la fecha y hora indicadas. Te esperamos en la nueva fecha para el servicio de $serviceName. ¡Gracias por tu comprensión!'
        : 'Este es un recordatorio de tu cita para el servicio de $serviceName. Te esperamos en la fecha y hora indicadas. ¡Gracias por confiar en nosotros!';
    
    // Cargar logo para el fondo
    Uint8List? logoBytes;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      logoBytes = data.buffer.asUint8List();
    } catch (e) {
      // Logo no disponible
    }
    
    // Cargar fuentes
    final fontData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final boldFont = pw.Font.ttf(fontData);
    
    final fontDataRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final regularFont = pw.Font.ttf(fontDataRegular);
    
    // Formatear datos
    final dateFormat = DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'es');
    final timeFormat = DateFormat('HH:mm');
    
    final formattedDate = _capitalizeFirst(dateFormat.format(appointmentTime));
    final formattedTime = timeFormat.format(appointmentTime);
    
    // Crear página del recordatorio
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // FONDO COMPLETO NEGRO
              pw.Positioned.fill(
                child: pw.Container(
                  color: backgroundColor,
                ),
              ),
              
              // LOGO GRANDE DIFUMINADO DE FONDO
              if (logoBytes != null)
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        image: pw.DecorationImage(
                          image: pw.MemoryImage(logoBytes),
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // BORDE INTERIOR (color según status)
              pw.Positioned.fill(
                child: pw.Container(
                  margin: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: primaryColor, width: 4),
                  ),
                ),
              ),
              
              // CONTENIDO PRINCIPAL
              pw.Positioned.fill(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(25),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Encabezado con logo y título CENTRADO
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Logo pequeño
                          if (logoBytes != null)
                            pw.Container(
                              width: 45,
                              height: 45,
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.ClipRRect(
                                horizontalRadius: 8,
                                verticalRadius: 8,
                                child: pw.Image(
                                  pw.MemoryImage(logoBytes),
                                  fit: pw.BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            pw.SizedBox(width: 45),
                          
                          // Título CENTRADO (cambia según status)
                          pw.Expanded(
                            child: pw.Center(
                              child: pw.Text(
                                titleText,
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 13,
                                  color: primaryColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          
                          // Espaciador para mantener el centro
                          pw.SizedBox(width: 45),
                        ],
                      ),
                      
                      pw.SizedBox(height: 20),
                      
                      // Nombre del cliente
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: primaryColor, width: 2),
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Text(
                          clientName.toUpperCase(),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 22,
                            color: textColor,
                            letterSpacing: 1.5,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      
                      pw.SizedBox(height: 18),
                      
                      // Mensaje profesional (texto negro sobre color de acento)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(15),
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        child: pw.Text(
                          messageText,
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 11,
                            color: backgroundColor,
                            height: 1.4,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      
                      pw.SizedBox(height: 18),
                      
                      // Fecha y hora (color de acento)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(18),
                        decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Column(
                          children: [
                            // Fecha
                            pw.Column(
                              children: [
                                pw.Text(
                                  isPostponed ? 'NUEVA FECHA' : 'FECHA',
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 10,
                                    color: backgroundColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  formattedDate,
                                  style: pw.TextStyle(
                                    font: regularFont,
                                    fontSize: 12,
                                    color: backgroundColor,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 12),
                            pw.Container(
                              width: 100,
                              height: 1,
                              color: backgroundColor.shade(0.3),
                            ),
                            pw.SizedBox(height: 12),
                            // Hora
                            pw.Column(
                              children: [
                                pw.Text(
                                  isPostponed ? 'NUEVA HORA' : 'HORA',
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 10,
                                    color: backgroundColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  formattedTime,
                                  style: pw.TextStyle(
                                    font: boldFont,
                                    fontSize: 28,
                                    color: backgroundColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      pw.SizedBox(height: 18),
                      
                      // Servicio
                      pw.Container(
                        padding: const pw.EdgeInsets.all(14),
                        width: double.infinity,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: primaryColor, width: 1.5),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'SERVICIO',
                              style: pw.TextStyle(
                                font: boldFont,
                                fontSize: 10,
                                color: primaryColor,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              serviceName,
                              style: pw.TextStyle(
                                font: regularFont,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      pw.SizedBox(height: 12),
                      
                      // Precio y depósito
                      pw.Row(
                        children: [
                          // PRECIO TOTAL
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(14),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: primaryColor, width: 1.5),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'PRECIO TOTAL',
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 9,
                                      color: primaryColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    '\$${price.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 16,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          // DEPÓSITO PAGADO (color de acento)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(14),
                              decoration: pw.BoxDecoration(
                                color: accentColor,
                                border: pw.Border.all(color: primaryColor, width: 1.5),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Text(
                                    'DEPÓSITO PAGADO',
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 9,
                                      color: backgroundColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    '\$${depositPaid.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 16,
                                      color: backgroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Notas (si existen)
                      if (notes != null && notes.isNotEmpty) ...[
                        pw.SizedBox(height: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: primaryColor.shade(0.5), width: 1),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'NOTAS ADICIONALES',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 9,
                                  color: primaryColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                notes,
                                style: pw.TextStyle(
                                  font: regularFont,
                                  fontSize: 11,
                                  color: textColor,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      pw.Spacer(),
                      
                      // Footer (mensaje según status)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: primaryColor, width: 2),
                          ),
                        ),
                        child: pw.Text(
                          isPostponed
                              ? '¡Nos vemos en la nueva fecha! No olvides llegar 5 minutos antes.'
                              : '¡Te esperamos! No olvides llegar 5 minutos antes.',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 11,
                            color: primaryColor,
                            letterSpacing: 0.5,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    // Guardar PDF temporalmente
    final output = await getTemporaryDirectory();
    final pdfFile = File('${output.path}/reminder_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    
    // Convertir PDF a imagen
    final imageFile = await _convertPdfToImage(pdfFile);
    
    // Eliminar PDF temporal
    await pdfFile.delete();
    
    return imageFile;
  }
  
  /// Convertir PDF a imagen JPG
  static Future<File> _convertPdfToImage(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    
    // Renderizar PDF a imagen con alta resolución
    await for (var page in Printing.raster(bytes, dpi: 300)) {
      final image = await page.toPng();
      
      // Guardar como JPG
      final output = await getTemporaryDirectory();
      final imageFile = File('${output.path}/reminder_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await imageFile.writeAsBytes(image);
      
      return imageFile;
    }
    
    throw Exception('No se pudo convertir el PDF a imagen');
  }
  
  /// Compartir recordatorio
  static Future<void> shareReminder(File imageFile) async {
    final params = ShareParams(
      files: [XFile(imageFile.path)],
      text: '¡Recordatorio de tu cita!',
    );
    await SharePlus.instance.share(params);
  }
  
  /// Eliminar archivo temporal
  static Future<void> deleteTemporaryFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// Capitalizar primera letra
  static String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}