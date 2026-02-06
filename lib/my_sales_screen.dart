import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'sale_detail_screen.dart'; // ← Import activo
import 'new_sale_screen.dart';
import 'client_search_screen.dart';
import 'change_password_screen.dart'; // al inicio

class MySalesScreen extends StatefulWidget {
  const MySalesScreen({super.key});

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> {
  List<dynamic> _ventas = [];
  bool _isLoading = false;
  String _error = '';
  final TextEditingController _ndocidController = TextEditingController();
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int _paginaActual = 1;
  bool _hayMasPaginas = false;
  String _vendedorNombre = 'Cargando...'; // 👈 Variable para el nombre dinámico

  final String _baseUrl = 'https://sistemasmipclista.com/api_ventas/api/v1';

  @override
  void initState() {
    super.initState();
    _cargarVendedorNombre(); // 👈 Cargar nombre al iniciar
    _cargarVentas();
  }

  // 👇 NUEVO: Método para cargar el nombre del vendedor
  Future<void> _cargarVendedorNombre() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('vendedor_nombre') ?? 'Vendedor';
    if (mounted) {
      setState(() {
        _vendedorNombre = nombre;
      });
    }
  }

  Future<void> _cargarVentas({bool nuevaBusqueda = false}) async {
    if (nuevaBusqueda) {
      _paginaActual = 1;
      _ventas.clear();
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }
    try {
      final params = <String, String>{};
      if (_ndocidController.text.trim().isNotEmpty) {
        params['ndocid'] = _ndocidController.text.trim();
      }
      if (_fechaDesde != null) {
        params['fecha_desde'] = _fechaDesde!.toIso8601String().split('T')[0];
      }
      if (_fechaHasta != null) {
        params['fecha_hasta'] = _fechaHasta!.toIso8601String().split('T')[0];
      }
      params['pagina'] = _paginaActual.toString();
      final uri = Uri.parse(
        '$_baseUrl/ventas/mis_ventas.php',
      ).replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final nuevasVentas = data['data'] as List?;
          if (nuevaBusqueda) {
            _ventas = nuevasVentas ?? [];
          } else {
            _ventas.addAll(nuevasVentas ?? []);
          }
          _hayMasPaginas = _ventas.length < 20 && (nuevasVentas?.length == 10);
        } else {
          _error = data['message'] ?? 'Error del servidor';
        }
      } else {
        _error = 'Error ${response.statusCode}';
      }
    } catch (e) {
      _error = 'No se pudo conectar al servidor';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _limpiarFiltros() {
    _ndocidController.clear();
    _fechaDesde = null;
    _fechaHasta = null;
    _cargarVentas(nuevaBusqueda: true);
  }

  int _parseVentaId(dynamic id) {
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Ventas'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _cargarVentas(nuevaBusqueda: true),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'App Ventas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Vendedor: $_vendedorNombre', // 👈 Nombre dinámico aquí
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'Mis Ventas',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.add_shopping_cart_outlined,
              title: 'Registrar Venta',
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewSaleScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.people_outlined,
              title: 'Clientes',
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientSearchScreen()),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.report_outlined,
              title: 'Reportes',
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente: Reportes')),
                );
              },
            ),
            const Divider(),
            _buildDrawerItem(
              context,
              icon: Icons.password_outlined,
              title: 'Cambiar Contraseña',
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.logout_outlined,
              title: 'Cerrar Sesión',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              children: [
                TextField(
                  controller: _ndocidController,
                  decoration: InputDecoration(
                    hintText: 'N° Documento (NDOCID)',
                    labelText: 'Buscar por documento',
                    prefixIcon: const Icon(Icons.badge),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFechaPicker(
                        label: 'Desde',
                        selectedDate: _fechaDesde,
                        onSelected: (date) =>
                            setState(() => _fechaDesde = date),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFechaPicker(
                        label: 'Hasta',
                        selectedDate: _fechaHasta,
                        onSelected: (date) =>
                            setState(() => _fechaHasta = date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _cargarVentas(nuevaBusqueda: true),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _limpiarFiltros,
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _error.isNotEmpty
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _ventas.isEmpty
                ? const Center(child: Text('No hay ventas.'))
                : ListView.builder(
                    itemCount: _ventas.length + (_hayMasPaginas ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _ventas.length && _hayMasPaginas) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (mounted) {
                                      setState(() {
                                        _paginaActual++;
                                      });
                                      _cargarVentas();
                                    }
                                  },
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : const Text('Cargar más'),
                          ),
                        );
                      }
                      final venta = _ventas[index];
                      double saldo = 0.0;
                      final rawSaldo = venta['saldo_pendiente'];
                      if (rawSaldo != null) {
                        if (rawSaldo is num) {
                          saldo = rawSaldo.toDouble();
                        } else if (rawSaldo is String) {
                          saldo = double.tryParse(rawSaldo) ?? 0.0;
                        }
                      }
                      final estadoTexto = saldo > 0 ? 'Pendiente' : 'Pagada';
                      final estadoColor = saldo > 0
                          ? Colors.orange
                          : Colors.green;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () {
                              final ventaId = _parseVentaId(venta['id_venta']);
                              if (ventaId > 0) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SaleDetailScreen(ventaId: ventaId),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        venta['cliente'] ??
                                            venta['nombre_cliente'] ??
                                            venta['CLIENTE'] ??
                                            'Cliente desconocido',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  'ID: ${venta['id_venta']} • ',
                                            ),
                                            TextSpan(
                                              text:
                                                  'Doc: ${venta['NDOCID'] ?? 'N/A'} • ',
                                            ),
                                            TextSpan(
                                              text:
                                                  'Fecha: ${venta['fecha_registro']?.split('T')[0] ?? 'N/A'}',
                                            ),
                                          ],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'S/ ${saldo.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: estadoColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        estadoTexto,
                                        style: TextStyle(
                                          color: estadoColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFechaPicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onSelected,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
      ),
      child: GestureDetector(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date != null) {
            onSelected(date);
          }
        },
        child: Text(
          selectedDate == null
              ? 'Seleccionar'
              : '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
