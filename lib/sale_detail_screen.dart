import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'add_payment_screen.dart'; // ← Importación clave
import 'package:printing/printing.dart'; // ← Para Printing
import 'utils/pdf_generator.dart'; // ← Para PdfGenerator

class SaleDetailScreen extends StatefulWidget {
  final int ventaId;

  const SaleDetailScreen({super.key, required this.ventaId});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Map<String, dynamic>? _venta;
  List<dynamic> _equipos = [];
  List<dynamic> _pagos = [];
  bool _isLoading = true;
  String _error = '';

  final String _baseUrl = 'https://sistemasmipclista.com/api_ventas/api/v1';

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ventas/detalle.php?id=${widget.ventaId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final detalle = data['data'] as Map<String, dynamic>?;
          if (context.mounted) {
            setState(() {
              _venta = detalle?['venta'] != null
                  ? Map<String, dynamic>.from(detalle!['venta'])
                  : null;
              _equipos = detalle?['equipos'] is List
                  ? List<dynamic>.from(detalle!['equipos'])
                  : [];
              _pagos = detalle?['pagos'] is List
                  ? List<dynamic>.from(detalle!['pagos'])
                  : [];
              _error = '';
            });
          }
        } else {
          if (context.mounted) {
            setState(() {
              _error = data['message'] ?? 'Error al cargar detalle';
            });
          }
        }
      } else {
        if (context.mounted) {
          setState(() {
            _error = 'Error del servidor: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _error = 'No se pudo conectar al servidor';
        });
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Nuevo método para calcular el total de pagos
  double _calcularTotalPagado() {
    double totalPagado = 0.0;
    for (var pago in _pagos) {
      final monto =
          double.tryParse(pago['MONTO_ABONO']?.toString() ?? '0.0') ?? 0.0;
      totalPagado += monto;
    }
    return totalPagado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Venta'), // const para mejor rendimiento
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.picture_as_pdf,
            ), // const para mejor rendimiento
            onPressed: () async {
              if (_venta == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No hay datos para generar PDF'),
                  ),
                );
                return;
              }

              if (!mounted) return;
              final loadingSnackBar = SnackBar(
                content: Row(
                  children: const [
                    // const para mejor rendimiento
                    CircularProgressIndicator(),
                    SizedBox(width: 10),
                    Text('Generando PDF...'),
                  ],
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(loadingSnackBar);

              try {
                final ventaCompleta = Map<String, dynamic>.from(_venta!);
                ventaCompleta['equipos'] = _equipos;
                ventaCompleta['pagos'] = _pagos;
                ventaCompleta['id_venta'] = widget.ventaId;

                final pdfFile = await PdfGenerator.generateSalePdf(
                  ventaCompleta,
                );

                if (!mounted) return;

                await Printing.sharePdf(
                  bytes: await pdfFile.readAsBytes(),
                  filename: 'venta_${widget.ventaId}.pdf',
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al generar PDF: ${e.toString()}'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // const para mejor rendimiento
          : _error.isNotEmpty
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(
                  color: Colors.red,
                ), // const para mejor rendimiento
              ),
            )
          : _venta == null
          ? const Center(
              child: Text('Venta no encontrada.'),
            ) // const para mejor rendimiento
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16), // const para mejor rendimiento
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datos del cliente
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ), // const para mejor rendimiento
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cliente: ${_venta?['cliente'] ?? 'N/A'}',
                            style: const TextStyle(
                              // const para mejor rendimiento
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ), // const para mejor rendimiento
                          Text('Documento: ${_venta?['NDOCID'] ?? 'N/A'}'),
                          Text(
                            'Fecha: ${_venta?['fecha_registro']?.toString().split('T').first ?? 'N/A'}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16), // const para mejor rendimiento
                  // Información financiera completa
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ), // const para mejor rendimiento
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            // const para mejor rendimiento
                            'Detalles Financieros',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(), // const para mejor rendimiento
                          _buildInfoRow('Precio Total', _venta?['PRECIO']),
                          _buildInfoRow('Envío', _venta?['ENVIO']),
                          if (_venta?['COMISION_PORCENTAJE'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                              ), // const para mejor rendimiento
                              child: Row(
                                children: [
                                  const Text(
                                    // const para mejor rendimiento
                                    'Comisión (%):',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(), // const para mejor rendimiento
                                  Text(
                                    '${_formatNumber(_venta?['COMISION_PORCENTAJE'])}%',
                                  ),
                                ],
                              ),
                            ),
                          _buildInfoRow(
                            'Comisión (S/)',
                            _venta?['COMISION_IMPORTE'],
                          ),
                          _buildInfoRow('Total Venta', _venta?['TOTAL']),
                          // _buildInfoRow('Adelanto', _venta?['ADELANTO']), // <-- Eliminado o comentado
                          _buildInfoRow(
                            'Total Pagado',
                            _calcularTotalPagado(),
                          ), // <-- Nueva línea
                          _buildInfoRow(
                            'Saldo Pendiente',
                            _venta?['saldo_pendiente'],
                            isSaldo: true,
                          ),
                          // Corrección para la Forma de Pago - Desbordamiento
                          if (_venta?['forma_pago'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Forma de Pago: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _venta!['forma_pago'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Corrección para Detalle FP - Desbordamiento
                          if (_venta?['detalle_forma_pago'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detalle FP: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _venta!['detalle_forma_pago'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Corrección para POS
                          if (_venta?['pos_ll'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'POS: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _venta!['pos_ll'].toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Corrección para Observación - Desbordamiento
                          if (_venta?['OBSERVACION'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Observación: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _venta!['OBSERVACION'].toString(),
                                      maxLines:
                                          3, // Permitir más líneas para una observación
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16), // const para mejor rendimiento
                  // Equipos
                  Text(
                    'Equipos (${_equipos.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ), // const para mejor rendimiento
                  ),
                  const SizedBox(height: 8), // const para mejor rendimiento
                  for (final equipo in _equipos)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                      ), // const para mejor rendimiento
                      child: ListTile(
                        title: Text(
                          equipo['descripcion']?.toString() ??
                              'Sin descripción',
                        ),
                        trailing: Text('S/ ${_formatNumber(equipo['precio'])}'),
                      ),
                    ),

                  const SizedBox(height: 16), // const para mejor rendimiento
                  // Pagos
                  Row(
                    children: [
                      Text(
                        'Pagos (${_pagos.length})',
                        style: const TextStyle(
                          // const para mejor rendimiento
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(), // const para mejor rendimiento
                      ElevatedButton.icon(
                        onPressed: () {
                          final saldoStr =
                              _venta?['saldo_pendiente']?.toString() ?? '0';
                          final saldo = double.tryParse(saldoStr) ?? 0.0;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddPaymentScreen(
                                ventaId: widget.ventaId,
                                saldoActual: saldo,
                              ),
                            ),
                          ).then((resultado) {
                            if (resultado == true && mounted) {
                              _cargarDetalle();
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.add,
                        ), // const para mejor rendimiento
                        label: const Text(
                          'Pago',
                        ), // const para mejor rendimiento
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // const para mejor rendimiento
                  for (final pago in _pagos)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                      ), // const para mejor rendimiento
                      child: Padding(
                        padding: const EdgeInsets.all(
                          12,
                        ), // const para mejor rendimiento
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  // const para mejor rendimiento
                                  'Monto:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(), // const para mejor rendimiento
                                Text(
                                  'S/ ${_formatNumber(pago['MONTO_ABONO'])}',
                                ),
                              ],
                            ),
                            if (pago['FORMAP'] != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ), // const para mejor rendimiento
                                child: Row(
                                  children: [
                                    const Text(
                                      // const para mejor rendimiento
                                      'Forma de Pago:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(), // const para mejor rendimiento
                                    Expanded(
                                      // <-- Para el desbordamiento aquí también
                                      child: Text(
                                        pago['FORMAP'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign
                                            .end, // Alinea el texto a la derecha
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (pago['FECHA_PAGO'] != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ), // const para mejor rendimiento
                                child: Row(
                                  children: [
                                    const Text(
                                      // const para mejor rendimiento
                                      'Fecha:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(), // const para mejor rendimiento
                                    Text(pago['FECHA_PAGO'].toString()),
                                  ],
                                ),
                              ),
                            if (pago['EXCESO'] != null &&
                                double.tryParse(pago['EXCESO'].toString()) != 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ), // const para mejor rendimiento
                                child: Row(
                                  children: [
                                    const Text(
                                      // const para mejor rendimiento
                                      'Exceso:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(), // const para mejor rendimiento
                                    Text('S/ ${_formatNumber(pago['EXCESO'])}'),
                                  ],
                                ),
                              ),
                            if (pago['OBSERVACION'] != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ), // const para mejor rendimiento
                                child: Row(
                                  // <-- También aquí para la observación del pago
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Observación: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        pago['OBSERVACION'].toString(),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // === MÉTODOS AUXILIARES ===
  Widget _buildInfoRow(String label, dynamic value, {bool isSaldo = false}) {
    if (value == null) return const SizedBox(); // const para mejor rendimiento
    final formattedValue = _formatNumber(value);
    final color = isSaldo
        ? (double.tryParse(formattedValue) ?? 0) > 0
              ? Colors.orange
              : Colors.green
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ), // const para mejor rendimiento
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ), // const para mejor rendimiento
          const Spacer(), // const para mejor rendimiento
          Text(
            isSaldo
                ? 'S/ $formattedValue'
                : 'S/ $formattedValue', // Corregir aquí si quieres el "S/" en Adelanto
            style: color != null ? TextStyle(color: color) : null,
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0.00';
    final str = value.toString().replaceAll(',', '.');
    final num = double.tryParse(str) ?? 0.0;
    return num.toStringAsFixed(2);
  }
}
