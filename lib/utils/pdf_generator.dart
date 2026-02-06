import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfGenerator {
  static Future<File> generateSalePdf(Map<String, dynamic> ventaData) async {
    final pdf = pw.Document();

    // Obtener logo desde URL
    pw.MemoryImage? logoImage;
    try {
      final logoResponse = await http.get(
        Uri.parse('https://sistemasmipclista.com/logo.png'),
      );
      if (logoResponse.statusCode == 200) {
        logoImage = pw.MemoryImage(logoResponse.bodyBytes);
      }
    } catch (e) {
      // Ignorar error de logo, continuar sin él
    }

    // Página 1 - Sintaxis corregida
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.ListView(
          children: [
            // Logo y título
            if (logoImage != null)
              pw.Center(child: pw.Image(logoImage, width: 100, height: 100))
            else
              pw.Center(
                child: pw.Text(
                  'EMPRESA',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'COMPROBANTE DE VENTA',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Datos del cliente
            pw.Text(
              'DATOS DEL CLIENTE',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ..._buildTableRows([
              ['Cliente:', ventaData['cliente'] ?? 'N/A'],
              ['Documento:', ventaData['ndocid'] ?? 'N/A'],
              [
                'Fecha:',
                ventaData['fecha_registro']?.toString().split('T').first ??
                    'N/A',
              ],
            ]),
            pw.SizedBox(height: 15),

            // Detalles financieros
            pw.Text(
              'DETALLES FINANCIEROS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ..._buildTableRows([
              if (ventaData['PRECIO'] != null)
                ['Precio Total:', 'S/ ${_formatNumber(ventaData['PRECIO'])}'],
              if (ventaData['ENVIO'] != null)
                ['Envío:', 'S/ ${_formatNumber(ventaData['ENVIO'])}'],
              if (ventaData['COMISION_PORCENTAJE'] != null)
                [
                  'Comisión (%):',
                  '${_formatNumber(ventaData['COMISION_PORCENTAJE'])}%',
                ],
              if (ventaData['COMISION_IMPORTE'] != null)
                [
                  'Comisión (S/):',
                  'S/ ${_formatNumber(ventaData['COMISION_IMPORTE'])}',
                ],
              if (ventaData['TOTAL'] != null)
                ['Total Venta:', 'S/ ${_formatNumber(ventaData['TOTAL'])}'],
              if (ventaData['ADELANTO'] != null)
                ['Adelanto:', 'S/ ${_formatNumber(ventaData['ADELANTO'])}'],
              if (ventaData['saldo_pendiente'] != null)
                [
                  'Saldo Pendiente:',
                  'S/ ${_formatNumber(ventaData['saldo_pendiente'])}',
                ],
              if (ventaData['forma_pago'] != null)
                ['Forma de Pago:', ventaData['forma_pago']],
              if (ventaData['pos_ll'] != null) ['POS:', ventaData['pos_ll']],
            ]),
            pw.SizedBox(height: 15),

            // Observación
            if (ventaData['OBSERVACION'] != null)
              pw.Column(
                children: [
                  pw.Text(
                    'OBSERVACIÓN',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    ventaData['OBSERVACION'],
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 15),
                ],
              ),

            // Equipos
            if (ventaData['equipos'] != null &&
                (ventaData['equipos'] as List).isNotEmpty) ...[
              pw.Text(
                'EQUIPOS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Descripción',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Precio',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var equipo in ventaData['equipos'] as List)
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            equipo['descripcion'] ?? 'Sin descripción',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'S/ ${_formatNumber(equipo['precio'])}',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 15),
            ],

            // Pagos
            if (ventaData['pagos'] != null &&
                (ventaData['pagos'] as List).isNotEmpty) ...[
              pw.Text(
                'PAGOS',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Fecha',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Monto',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Forma Pago',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Exceso',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Observación',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var pago in ventaData['pagos'] as List)
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            pago['FECHA_PAGO'] ?? '',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'S/ ${_formatNumber(pago['MONTO_ABONO'])}',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            pago['FORMAP'] ?? '',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            pago['EXCESO'] != null &&
                                    double.tryParse(
                                          pago['EXCESO'].toString(),
                                        ) !=
                                        0
                                ? 'S/ ${_formatNumber(pago['EXCESO'])}'
                                : '',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            pago['OBSERVACION'] ?? '',
                            style: pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],

            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                'Gracias por su preferencia!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Guardar PDF
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/venta_${ventaData['id_venta'] ?? '0'}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static List<pw.Widget> _buildTableRows(List<List<String>> data) {
    return data.map((row) {
      return pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              row[0],
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(row[1], style: pw.TextStyle(fontSize: 10)),
          ),
        ],
      );
    }).toList();
  }

  static String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    final str = value.toString().replaceAll(',', '.');
    final num = double.tryParse(str) ?? 0.0;
    return num.toStringAsFixed(2);
  }
}
