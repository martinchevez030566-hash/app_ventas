import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_detail_screen.dart';
import 'pdf_service.dart';

class ClientSearchScreen extends StatefulWidget {
  const ClientSearchScreen({super.key});

  @override
  State<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends State<ClientSearchScreen> {
  final TextEditingController _docController = TextEditingController();
  List<dynamic> _ventas = [];
  bool _isLoading = false;
  String? _mensaje;

  final String _baseUrl =
      'https://sistemasmipclista.com/api_ventas/api/v1/clientes/buscar_ventas.php';

  final String _pdfEndpoint =
      'https://sistemasmipclista.com/api_ventas/api/v1/documentos/generar_pdf.php';

  final PDFService _pdfService = PDFService();

  // ============================================================================
  // BÚSQUEDA (FUNCIONALIDAD ORIGINAL 100% PRESERVADA)
  // ============================================================================

  Future<void> _buscarVentas() async {
    final doc = _docController.text.trim();
    if (doc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un número de documento')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _isLoading = true;
      _mensaje = null;
      _ventas = [];
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'documento': doc}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          setState(() {
            _ventas = data['data'] ?? [];
            _mensaje = null;
          });
        }
      } else if (data['status'] == 'error' && response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _mensaje = 'Cliente no encontrado';
          });
        }
      } else {
        final errorMsg = data['message'] ?? 'Error desconocido';
        if (mounted) {
          setState(() {
            _mensaje = errorMsg;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensaje = 'No se pudo conectar al servidor';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================================
  // PDF - GENERACIÓN DIRECTA (SIN DEPENDENCIAS ADICIONALES)
  // ============================================================================

  Future<Uint8List> _generarPDFBytes(
    String ctd,
    String cnumser,
    String cnumdoc,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Sesión expirada');
    }

    final response = await http.post(
      Uri.parse(_pdfEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'ctd': ctd, 'cnumser': cnumser, 'cnumdoc': cnumdoc}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Opción 1: base64
      if (data['pdf_base64'] != null) {
        return base64Decode(data['pdf_base64']);
      }

      // Opción 2: URL
      if (data['pdf_url'] != null) {
        final urlResponse = await http.get(Uri.parse(data['pdf_url']));
        if (urlResponse.statusCode == 200) {
          return urlResponse.bodyBytes;
        }
      }

      throw Exception('Respuesta inválida del servidor PDF');
    } else {
      final errorMsg =
          jsonDecode(response.body)['message'] ?? 'Error desconocido';
      throw Exception(
        'Error al generar PDF: $errorMsg (Código ${response.statusCode})',
      );
    }
  }

  Future<void> _verPDF(
    String ctd,
    String cnumser,
    String cnumdoc,
    String descripcion,
  ) async {
    try {
      _mostrarLoading('Generando documento...');

      final pdfBytes = await _generarPDFBytes(ctd, cnumser, cnumdoc);

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      await _pdfService.mostrarPDF(context, pdfBytes, descripcion);
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _mostrarError(
        'Error al generar PDF: ${e.toString().split(RegExp(r'[:\n]')).first}',
      );
    }
  }

  Future<void> _compartirPDF(
    String ctd,
    String cnumser,
    String cnumdoc,
    String filename,
  ) async {
    try {
      _mostrarLoading('Preparando documento...');

      final pdfBytes = await _generarPDFBytes(ctd, cnumser, cnumdoc);

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      // Intentar compartir usando PDFService (seguro con try-catch)
      try {
        await _pdfService.compartirPDF(pdfBytes, filename);
      } catch (e) {
        // Si compartir falla (share_plus no instalado), mostrar mensaje amigable
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '✅ PDF generado. Usa el botón "Ver PDF" para compartir manualmente.',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Documento listo para compartir'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _mostrarError(
        'Error al preparar documento: ${e.toString().split(RegExp(r'[:\n]')).first}',
      );
    }
  }

  void _mostrarDetalle(String ctd, String cnumser, String cnumdoc) {
    if (ctd.isEmpty || cnumser.isEmpty || cnumdoc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos incompletos para el detalle')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClientDetailScreen(ctd: ctd, cnumser: cnumser, cnumdoc: cnumdoc),
      ),
    );
  }

  void _mostrarMenuOpciones(BuildContext context, dynamic venta) {
    final ctd = venta['CTD']?.toString() ?? '';
    final cnumser = venta['CNUMSER']?.toString() ?? '';
    final cnumdoc = venta['CNUMDOC']?.toString() ?? '';
    final cliente = venta['NOMCLIE'] ?? 'Cliente';
    final numeroDoc = venta['NUMERO_DOC'] ?? '';
    final descripcion = '$numeroDoc | $cliente';
    final filename = '$numeroDoc.pdf';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'CTD: $ctd | Serie: $cnumser | Doc: $cnumdoc',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              // OPCIÓN 1: Mostrar Detalle
              ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text(
                  'Mostrar Detalle',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDetalle(ctd, cnumser, cnumdoc);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // OPCIÓN 2: Ver PDF
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.green),
                title: const Text(
                  'Ver PDF',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _verPDF(ctd, cnumser, cnumdoc, descripcion);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              // OPCIÓN 3: Compartir
              ListTile(
                leading: const Icon(Icons.share, color: Colors.orange),
                title: const Text(
                  'Compartir',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _compartirPDF(ctd, cnumser, cnumdoc, filename);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _mostrarLoading(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(mensaje),
          ],
        ),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================================
  // BUILD - ARQUITECTURA TÁCTIL SÓLIDA (¡SIN CONFLICTOS!)
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Cliente'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de búsqueda con lupa
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _docController,
                    decoration: InputDecoration(
                      labelText: 'N° Documento del cliente',
                      border: OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _buscarVentas(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _buscarVentas,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Mensaje de error o "no encontrado"
            if (_mensaje != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _mensaje!,
                  style: TextStyle(
                    color: _mensaje == 'Cliente no encontrado'
                        ? Colors.red
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            // Indicador de carga
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            // Lista de ventas - ¡ARQUITECTURA TÁCTIL CORREGIDA!
            if (!_isLoading && _ventas.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _ventas.length,
                  itemBuilder: (context, index) {
                    final v = _ventas[index];
                    final fecha = v['FECHA_VENTA'] ?? 'N/A';
                    final docVenta = v['NUMERO_DOC'] ?? 'N/A';
                    final cliente = v['NOMCLIE'] ?? 'Cliente';
                    final total =
                        double.tryParse(v['TOTAL']?.toString() ?? '0') ?? 0;
                    final vendedor = v['VENDEDOR'] ?? 'N/A';
                    final ctd = v['CTD']?.toString() ?? '';
                    final cnumser = v['CNUMSER']?.toString() ?? '';
                    final cnumdoc = v['CNUMDOC']?.toString() ?? '';

                    // ✅ ESTRUCTURA TÁCTIL SÓLIDA: Sin conflictos
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Stack(
                        children: [
                          // ✅ ÁREA TÁCTIL PRINCIPAL: Tap en tarjeta → detalle
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _mostrarDetalle(ctd, cnumser, cnumdoc),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          // ✅ CONTENIDO VISIBLE
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Fecha: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: fecha),
                                          ],
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: 'Doc: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: docVenta),
                                          ],
                                        ),
                                        style: const TextStyle(fontSize: 14),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Vendedor: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: vendedor),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Total: S/ ${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ✅ BOTÓN "⋮" - ¡ESTABLE Y SIN CONFLICTOS!
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              behavior: HitTestBehavior
                                  .opaque, // ← Bloquea toques del InkWell padre
                              onTap: () => _mostrarMenuOpciones(context, v),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.transparent,
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Mensaje inicial
            if (!_isLoading && _ventas.isEmpty && _mensaje == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'Ingrese un número de documento y presione la lupa para buscar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
