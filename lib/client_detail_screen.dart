import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClientDetailScreen extends StatefulWidget {
  final String ctd;
  final String cnumser;
  final String cnumdoc;

  const ClientDetailScreen({
    super.key,
    required this.ctd,
    required this.cnumser,
    required this.cnumdoc,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<dynamic> _detalles = [];
  bool _isLoading = true;
  String? _error;

  final String _baseUrl =
      'https://sistemasmipclista.com/api_ventas/api/v1/clientes/detalle_venta.php';

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).popAndPushNamed('/login');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/clientes/detalle_venta.php'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'CTD': widget.ctd,
          'CNUMSER': widget.cnumser,
          'CNUMDOC': widget.cnumdoc,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          setState(() {
            _detalles = data['data'] ?? [];
            _error = null;
          });
        }
      } else {
        final errorMsg = data['message'] ?? 'Error al cargar el detalle';
        if (mounted) {
          setState(() {
            _error = errorMsg;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo conectar al servidor';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Venta'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _detalles.isEmpty
          ? const Center(
              child: Text('No se encontraron productos en esta venta'),
            )
          : ListView.builder(
              itemCount: _detalles.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final item = _detalles[index];
                final codigo = item['F6_CCODIGO'] ?? 'N/A';
                final descripcion = item['F6_CDESCRI'] ?? 'Sin descripción';
                final cantidad =
                    double.tryParse(item['F6_NCANTID']?.toString() ?? '0') ?? 0;
                final precio =
                    double.tryParse(item['F6_NPRECIO']?.toString() ?? '0') ?? 0;
                final totalItem = (cantidad * precio);
                final familia = item['FAMILIA'] ?? '';
                final ctipo = item['CTIPO'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0), // 👈 Más espacio
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Código y tipo/familia (si existen)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Código: $codigo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ctipo.isNotEmpty || familia.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ctipo.isNotEmpty ? ctipo : familia,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Descripción completa (hasta 3 líneas)
                        Text(
                          descripcion,
                          style: const TextStyle(fontSize: 15),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Cantidad, precio y total en fila
                        // Cantidad y precio unitario en una línea
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cantidad.toStringAsFixed(2)} uds',
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              'S/ ${precio.toStringAsFixed(2)} c/u',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Total en su propia línea
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total: S/ ${totalItem.toStringAsFixed(2)}',
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
                );
              },
            ),
    );
  }
}
