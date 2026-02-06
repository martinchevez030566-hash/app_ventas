// pdf_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';

class PDFService {
  static const String baseUrl =
      'https://sistemasmipclista.com/api_ventas/api/v1';

  /// Obtener token almacenado
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Generar PDF desde el backend
  Future<PDFResponse> generarPDF(
    String venId, {
    bool incluirBase64 = true,
  }) async {
    try {
      debugPrint('📄 Generando PDF para: $venId');

      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Token no disponible. Por favor, inicie sesión.');
      }

      final url = '$baseUrl/documentos/generar_pdf.php';
      debugPrint('🌐 URL: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'ven_id': venId,
              'incluir_base64': incluirBase64,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Tiempo de espera agotado al generar PDF');
            },
          );

      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint(
        '📄 Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          return PDFResponse.fromJson(data['data']);
        } else {
          throw Exception(
            data['message'] ?? 'Error desconocido al generar PDF',
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception(
          'Sesión expirada. Por favor, inicie sesión nuevamente.',
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Solicitud inválida');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error en generarPDF: $e');
      rethrow;
    }
  }

  /// Descargar PDF y convertir de base64
  Uint8List decodificarPDFBase64(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      debugPrint('❌ Error decodificando base64: $e');
      throw Exception('Error al decodificar PDF');
    }
  }

  /// Guardar PDF en almacenamiento local
  Future<File> guardarPDFLocal(Uint8List pdfBytes, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      debugPrint('✅ PDF guardado en: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('❌ Error guardando PDF: $e');
      throw Exception('Error al guardar PDF localmente');
    }
  }

  /// Descargar PDF desde URL
  Future<Uint8List> descargarPDFDesdeURL(String url) async {
    try {
      debugPrint('⬇️ Descargando PDF desde: $url');

      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse(url),
            headers: token != null ? {'Authorization': 'Bearer $token'} : {},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        debugPrint('✅ PDF descargado: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        throw Exception('Error al descargar PDF: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error descargando PDF: $e');
      rethrow;
    }
  }

  /// Mostrar PDF en pantalla
  Future<void> mostrarPDF(
    BuildContext context,
    Uint8List pdfBytes,
    String titulo,
  ) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PDFViewerScreen(pdfBytes: pdfBytes, titulo: titulo),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error mostrando PDF: $e');
      throw Exception('Error al mostrar PDF');
    }
  }

  /// Compartir PDF
  Future<void> compartirPDF(Uint8List pdfBytes, String filename) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      debugPrint('✅ PDF compartido: $filename');
    } catch (e) {
      debugPrint('❌ Error compartiendo PDF: $e');
      throw Exception('Error al compartir PDF');
    }
  }

  /// Imprimir PDF
  Future<void> imprimirPDF(Uint8List pdfBytes) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      debugPrint('✅ PDF enviado a impresora');
    } catch (e) {
      debugPrint('❌ Error imprimiendo PDF: $e');
      throw Exception('Error al imprimir PDF');
    }
  }
}

/// Modelo de respuesta del PDF
class PDFResponse {
  final String venId;
  final String filename;
  final String pdfUrl;
  final double sizeKb;
  final int sizeBytes;
  final String tipoDocumento;
  final String serie;
  final String correlativo;
  final String? pdfBase64;
  final DateTime generadoEn;

  PDFResponse({
    required this.venId,
    required this.filename,
    required this.pdfUrl,
    required this.sizeKb,
    required this.sizeBytes,
    required this.tipoDocumento,
    required this.serie,
    required this.correlativo,
    this.pdfBase64,
    required this.generadoEn,
  });

  factory PDFResponse.fromJson(Map<String, dynamic> json) {
    return PDFResponse(
      venId: json['ven_id'],
      filename: json['filename'],
      pdfUrl: json['pdf_url'],
      sizeKb: (json['size_kb'] as num).toDouble(),
      sizeBytes: json['size_bytes'],
      tipoDocumento: json['tipo_documento'],
      serie: json['serie'],
      correlativo: json['correlativo'],
      pdfBase64: json['pdf_base64'],
      generadoEn: DateTime.parse(json['generado_en']),
    );
  }

  /// Obtener bytes del PDF
  Uint8List? getPDFBytes() {
    if (pdfBase64 != null) {
      return base64Decode(pdfBase64!);
    }
    return null;
  }
}

/// Pantalla para visualizar PDF
class PDFViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String titulo;

  const PDFViewerScreen({
    super.key,
    required this.pdfBytes,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await PDFService().compartirPDF(pdfBytes, '$titulo.pdf');
            },
            tooltip: 'Compartir',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              await PDFService().imprimirPDF(pdfBytes);
            },
            tooltip: 'Imprimir',
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}
