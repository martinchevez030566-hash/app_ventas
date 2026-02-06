// --- START OF FILE new_sale_screen.dart.txt ---

import 'dart:async' show TimeoutException;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
// ignore: unused_import
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'package:image/image.dart' as img; // ← Importa el paquete image

// NUEVO: Enum para el tipo de comisión
enum TipoComision {
  porcentaje,
  importe,
  ninguna, // Opción para no aplicar comisión
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  // Controllers
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _nombreClienteController =
      TextEditingController();
  final TextEditingController _ubigeoController = TextEditingController();
  final TextEditingController _precioTotalController =
      TextEditingController(); // Este ahora representará la suma de 'precio_real_venta'
  final TextEditingController _envioController = TextEditingController(
    text: '0.00',
  ); // Inicializado por defecto
  final TextEditingController _comisionPctController = TextEditingController(
    text: '0.00',
  ); // Inicializado por defecto
  final TextEditingController _adelantoController = TextEditingController(
    text: '0.00',
  ); // Inicializado por defecto
  final TextEditingController _observacionController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _comisionImporteController =
      TextEditingController(
        text: '0.00',
      ); // NUEVO: Controlador para comisión por importe
  final TextEditingController _cambioController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  // Data lists
  List<dynamic> _categorias = [];
  List<dynamic> _formasPago = [];
  List<dynamic> _posList = [];
  List<dynamic> _regalos = [];
  final List<File> _selectedImages =
      []; // Lista para almacenar las fotos seleccionadas
  // MODIFICADO: _equiposSeleccionados ahora contendrá 'precio_original' y 'precio_real_venta'
  final List<Map<String, dynamic>> _equiposSeleccionados = [];
  final List<Map<String, dynamic>> _regalosSeleccionados = [];

  // Selected values
  int? _formaPagoAdelantoSeleccionada;
  int? _formaPagoSaldoSeleccionada;
  int? _posSeleccionado;

  // State management
  bool _isLoading = false;
  bool _isLoadingInitialData = true;
  final Map<String, bool> _loadingStatus = {
    'categorias': false,
    'formasPago': false,
    'pos': false,
    'regalos': false,
  };
  String _error = '';
  String? _loadingError;
  String _fuenteCliente = '';
  String _descripcionUbigeo = '';
  String _tipoProducto = 'equipo';

  // Resumen de Venta (NUEVAS VARIABLES Y AJUSTES)
  TipoComision _tipoComisionSeleccionada =
      TipoComision.ninguna; // Valor por defecto
  double _totalEquiposComponentes = 0.0; // Suma de 'precio_real_venta'
  double _comisionCalculada = 0.0;
  double _subtotalVenta = 0.0;
  double _saldoPendiente = 0.0;
  bool _adelantoInvalido = false; // Estado para la validación del adelanto
  double _descuentoCalculado = 0.0; // NUEVO: Para el descuento

  // Constants
  final String _baseUrl = 'https://sistemasmipclista.com/api_ventas/api/v1';
  static const Duration _requestTimeout = Duration(seconds: 10);

  // NUEVOS: FocusNodes para los campos numéricos que se deben seleccionar al enfocar
  final FocusNode _envioFocusNode = FocusNode();
  final FocusNode _comisionPctFocusNode = FocusNode();
  final FocusNode _comisionImporteFocusNode = FocusNode();
  final FocusNode _adelantoFocusNode = FocusNode();
  final FocusNode _documentoFocusNode = FocusNode();

  // ============================================================================
  // HELPERS DE FORMATEO Y CONVERSIÓN
  // ============================================================================

  /// Formatea un precio de forma segura a String con 2 decimales
  String _formatPrecio(dynamic precio) {
    if (precio == null) return '0.00';

    if (precio is double) {
      return precio.toStringAsFixed(2);
    } else if (precio is int) {
      return precio.toDouble().toStringAsFixed(2);
    } else if (precio is String) {
      final parsed = double.tryParse(precio);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }

    return '0.00';
  }

  /// Convierte cualquier tipo de precio a double
  double _parsePrecio(dynamic precio) {
    if (precio == null) return 0.0;

    if (precio is double) {
      return precio;
    } else if (precio is int) {
      return precio.toDouble();
    } else if (precio is String) {
      return double.tryParse(precio) ?? 0.0;
    }

    return 0.0;
  }

  // NUEVO: Función auxiliar para manejar el foco y seleccionar el texto
  void Function() _onFocusChange(
    TextEditingController controller,
    FocusNode focusNode,
  ) {
    return () {
      if (focusNode.hasFocus) {
        // Asegúrate de que el widget ya está renderizado antes de intentar seleccionar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.text.isNotEmpty) {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          }
        });
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _envioController.addListener(_calcularResumen);
    _comisionPctController.addListener(_calcularResumen);
    _comisionImporteController.addListener(_calcularResumen);
    _adelantoController.addListener(_calcularResumen);

    WidgetsBinding.instance.addPostFrameCallback((_) => _calcularResumen());

    _envioFocusNode.addListener(
      _onFocusChange(_envioController, _envioFocusNode),
    );
    _comisionPctFocusNode.addListener(
      _onFocusChange(_comisionPctController, _comisionPctFocusNode),
    );
    _comisionImporteFocusNode.addListener(
      _onFocusChange(_comisionImporteController, _comisionImporteFocusNode),
    );
    _adelantoFocusNode.addListener(
      _onFocusChange(_adelantoController, _adelantoFocusNode),
    );
    _documentoFocusNode.addListener(
      _onFocusChange(_documentoController, _documentoFocusNode),
    );
    // NUEVO: Debug después de 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('📊 DEBUG Estado de listas:');
      debugPrint('   Formas de pago: ${_formasPago.length}');
      debugPrint('   POS: ${_posList.length}');
      debugPrint('   Regalos: ${_regalos.length}');
      debugPrint('   Categorías: ${_categorias.length}');
    });
  }

  @override
  void dispose() {
    _documentoController.dispose();
    _nombreClienteController.dispose();
    _ubigeoController.dispose();
    _precioTotalController.dispose();
    _envioController.dispose();
    _comisionPctController.dispose();
    _adelantoController.dispose();
    _observacionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _comisionImporteController.dispose(); // Disponer del nuevo controlador

    // Eliminar listeners
    _envioController.removeListener(_calcularResumen);
    _comisionPctController.removeListener(_calcularResumen);
    _comisionImporteController.removeListener(_calcularResumen);
    _adelantoController.removeListener(_calcularResumen);

    // NUEVO: Disponer los FocusNodes
    _envioFocusNode.dispose();
    _comisionPctFocusNode.dispose();
    _comisionImporteFocusNode.dispose();
    _adelantoFocusNode.dispose();
    _documentoFocusNode.dispose();
    _cambioController.dispose();
    _observacionesController.dispose(); // Si lo añadiste

    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
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

    if (!mounted) return;
    setState(() {
      _isLoadingInitialData = true;
      _loadingError = null;
    });

    debugPrint('🚀 Iniciando carga de datos iniciales...');
    debugPrint('🔑 Token disponible: ${token.length} caracteres');

    // CARGAR UNO POR UNO PARA VER TODOS LOS LOGS
    debugPrint('\n📍 Paso 1/4: Cargando categorías...');
    await _cargarCategorias(token, tipo: _tipoProducto);
    _updateLoadingStatus('categorias');
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('\n📍 Paso 2/4: Cargando formas de pago...');
    await _cargarFormasPago(token);
    _updateLoadingStatus('formasPago');
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('\n📍 Paso 3/4: Cargando POS...');
    await _cargarPOS(token);
    _updateLoadingStatus('pos');
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('\n📍 Paso 4/4: Cargando regalos...');
    //await _cargarRegalos(token);
    //_updateLoadingStatus('regalos');

    debugPrint('\n✅ Carga de datos finalizada');
    debugPrint('📊 Resumen:');
    debugPrint('   Categorías: ${_categorias.length}');
    debugPrint('   Formas de pago: ${_formasPago.length}');
    debugPrint('   POS: ${_posList.length}');
    debugPrint('   Regalos: ${_regalos.length}');

    if (mounted) {
      setState(() => _isLoadingInitialData = false);
    }
  }

  void _updateLoadingStatus(String key) {
    if (mounted) {
      setState(() => _loadingStatus[key] = true);
    }
  }

  String _getLabelForKey(String key) {
    const labels = {
      'categorias': 'Categorías',
      'formasPago': 'Formas de pago',
      'pos': 'POS',
      'regalos': 'Regalos',
    };
    return labels[key] ?? key;
  }

  Future<void> _agregarEquipo() async {
    debugPrint('🔍 [TRACE] Iniciando _agregarEquipo()');

    if (_categorias.isEmpty) {
      debugPrint('🔄 Recargando categorías para tipo: $_tipoProducto');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null && token.isNotEmpty) {
        await _cargarCategorias(token, tipo: _tipoProducto);
      }
    }

    if (_categorias.isEmpty) {
      debugPrint('⚠️ [TRACE] _categorias está vacío después de recargar');
      _showMessage('No hay categorías disponibles para $_tipoProducto');
      return;
    }

    debugPrint('📊 [TRACE] _categorias.length = ${_categorias.length}');

    try {
      final categoriasValidas = _categorias
          .whereType<Map<String, dynamic>>()
          .toList();

      if (categoriasValidas.isEmpty) {
        debugPrint('❌ [TRACE] No hay categorías con tipo válido');
        _showMessage('Error: formato de categorías inválido');
        return;
      }

      final selectedCategoria = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: Text('Seleccionar Categoría ($_tipoProducto)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: categoriasValidas.isEmpty
                  ? const Center(child: Text('No hay categorías disponibles'))
                  : ListView.builder(
                      itemCount: categoriasValidas.length,
                      itemBuilder: (context, index) {
                        final categoria = categoriasValidas[index];
                        final nombre =
                            categoria['CATEGORIA']?.toString() ?? 'Sin nombre';
                        final prefijo = categoria['PREFIJO']?.toString() ?? '';

                        if (prefijo.isEmpty) {
                          debugPrint(
                            '⚠️ [TRACE] Categoría sin prefijo: $nombre',
                          );
                        }

                        return ListTile(
                          title: Text(nombre),
                          subtitle: Text(
                            'Prefijo: ${prefijo.isNotEmpty ? prefijo.trim() : "N/A"}',
                          ),
                          onTap: () {
                            debugPrint(
                              '👆 [TRACE] Categoría seleccionada: $nombre',
                            );
                            Navigator.pop(context, categoria);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  debugPrint('❌ [TRACE] Diálogo cancelado');
                  Navigator.pop(context, null);
                },
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (selectedCategoria == null) {
        debugPrint('ℹ️ [TRACE] No se seleccionó categoría');
        return;
      }

      debugPrint('✅ [TRACE] Categoría seleccionada: $selectedCategoria');

      if (!selectedCategoria.containsKey('CATEGORIA') ||
          !selectedCategoria.containsKey('PREFIJO')) {
        _showMessage('Error: categoría incompleta');
        return;
      }

      final precio = await _ingresarPrecio(
        selectedCategoria['CATEGORIA']?.toString() ?? 'Producto',
      );

      if (!mounted) return;

      if (precio == null || precio <= 0) {
        debugPrint('⚠️ [TRACE] Precio inválido o cancelado');
        return;
      }

      final prefijoRaw = selectedCategoria['PREFIJO']?.toString() ?? '';
      final prefijoLimpio = prefijoRaw.replaceAll(' ', '').trim();

      if (prefijoLimpio.isEmpty) {
        _showMessage('Error: categoría sin prefijo válido');
        return;
      }

      final codigo = '$prefijoLimpio${precio.toInt()}';

      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 [TRACE] Formando código de producto');
      debugPrint('   Tipo: $_tipoProducto');
      debugPrint('   Prefijo RAW: "$prefijoRaw"');
      debugPrint('   Prefijo LIMPIO: "$prefijoLimpio"');
      debugPrint('   Precio: ${precio.toInt()}');
      debugPrint('   Código FINAL: "$codigo"');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final producto = await _buscarProducto(codigo);

      if (!mounted) return;

      if (producto != null) {
        // NUEVO: Ingresar cantidad
        final cantidad = await _ingresarCantidad(
          producto['DESCRIPCION_EQUIPO']?.toString() ?? 'Producto',
        );

        if (!mounted) return;

        if (cantidad == null || cantidad <= 0) {
          debugPrint('⚠️ [TRACE] Cantidad inválida o cancelada');
          return;
        }

        setState(() {
          _equiposSeleccionados.add({
            'codigo': producto['CODIGO']?.toString() ?? codigo,
            'descripcion':
                producto['DESCRIPCION_EQUIPO']?.toString() ??
                'Producto sin descripción',
            'precio_original': _parsePrecio(producto['PRECIO']),
            'precio_real_venta': _parsePrecio(producto['PRECIO']),
            'precio_real_controller': TextEditingController(
              text: _formatPrecio(_parsePrecio(producto['PRECIO'])),
            ),
            'cantidad': cantidad, // NUEVO CAMPO
          });
          _calcularResumen();
        });
        debugPrint(
          '✅ [TRACE] Equipo agregado exitosamente con cantidad: $cantidad',
        );
      } else {
        _showMessage('Producto no encontrado con código: $codigo');
      }
    } catch (e, stack) {
      debugPrint('💥 [ERROR] Excepción en _agregarEquipo: $e');
      debugPrint('📋 StackTrace: $stack');
      if (mounted) {
        _showMessage('Error al procesar categoría. Intente nuevamente.');
      }
    }
  }

  Future<double?> _ingresarPrecio(String categoria) async {
    final controller = TextEditingController();

    final resultado = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Precio para $categoria'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Precio (S/)',
              hintText: 'Ej: 2499',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final precio = double.tryParse(value.trim());
              if (precio != null && precio > 0) {
                Navigator.of(dialogContext).pop(precio);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value != null && value > 0) {
                  Navigator.of(dialogContext).pop(value);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese un precio válido mayor a 0'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 200));
    controller.dispose();

    return resultado;
  }

  Future<void> _cargarCategorias(String token, {String? tipo}) async {
    try {
      String url = '$_baseUrl/productos/lista.php';
      if (tipo != null && tipo.isNotEmpty) {
        url += '?tipo=$tipo';
        debugPrint('🌐 [API] URL: $url');
      }

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);

      debugPrint('📡 [API] Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        debugPrint('📄 [API] Response: ${response.body}');

        if (data['status'] == 'success' && mounted) {
          final List<dynamic> rawData = data['data'] ?? [];
          final List<Map<String, dynamic>> categoriasValidas = [];

          for (var item in rawData) {
            try {
              Map<String, dynamic> categoria;

              if (item is Map<String, dynamic>) {
                categoria = item;
              } else if (item is Map) {
                categoria = Map<String, dynamic>.from(item);
              } else {
                debugPrint(
                  '⚠️ Item ignorado (tipo inválido): ${item.runtimeType}',
                );
                continue;
              }

              if (categoria.containsKey('CATEGORIA') &&
                  categoria.containsKey('PREFIJO') &&
                  categoria['CATEGORIA'] != null &&
                  categoria['PREFIJO'] != null) {
                categoriasValidas.add(categoria);
              } else {
                debugPrint(
                  '⚠️ Categoría ignorada (campos faltantes): $categoria',
                );
              }
            } catch (e) {
              debugPrint('❌ Error procesando item: $e');
            }
          }

          if (mounted) {
            setState(() {
              _categorias = categoriasValidas;
            });
            debugPrint(
              '✅ Categorías cargadas (tipo: $tipo): ${categoriasValidas.length}',
            );
          }
        }
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode} al cargar categorías');
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout al cargar categorías');
    } catch (e) {
      debugPrint('❌ Error al cargar categorías: $e');
    }
  }

  Future<void> _cargarFormasPago(String token) async {
    debugPrint('🔄 Iniciando carga de formas de pago...');
    debugPrint('🔑 Token: ${token.substring(0, 20)}...');

    try {
      final url = '$_baseUrl/formas_pago/lista.php';
      debugPrint('🌐 URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);

      debugPrint('📡 Formas Pago - Status: ${response.statusCode}');
      debugPrint('📄 Formas Pago - Body completo: ${response.body}');
      debugPrint('📋 Formas Pago - Headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('📦 Formas Pago - Data parseado: $data');
          debugPrint('📦 Formas Pago - Tipo: ${data.runtimeType}');
          debugPrint('📦 Formas Pago - Status: ${data['status']}');
          debugPrint('📦 Formas Pago - Message: ${data['message']}');

          if (data['status'] == 'success') {
            final rawData = data['data'];
            debugPrint('📦 Formas Pago - Data raw: $rawData');
            debugPrint('📦 Formas Pago - Data tipo: ${rawData.runtimeType}');

            if (rawData is List) {
              debugPrint('✅ Formas de pago encontradas: ${rawData.length}');

              for (var i = 0; i < rawData.length; i++) {
                debugPrint('   [$i] ${rawData[i]}');
              }

              if (mounted) {
                setState(() {
                  _formasPago = rawData;
                  if (_formasPago.isNotEmpty) {
                    // --- CORRECCIÓN AQUÍ ---
                    // Usar int.tryParse para convertir el String 'ID' a un int?
                    _formaPagoAdelantoSeleccionada = int.tryParse(
                      _formasPago[0]['ID'].toString(),
                    );
                    _formaPagoSaldoSeleccionada = int.tryParse(
                      _formasPago[0]['ID'].toString(),
                    );
                    // -----------------------

                    debugPrint('✅ Valores asignados:');
                    debugPrint('   Adelanto: $_formaPagoAdelantoSeleccionada');
                    debugPrint('   Saldo: $_formaPagoSaldoSeleccionada');
                  }
                });
              }
            } else {
              debugPrint('❌ Data no es una lista: ${rawData.runtimeType}');
            }
          } else {
            debugPrint('⚠️ Status no exitoso: ${data['status']}');
            debugPrint('⚠️ Message: ${data['message']}');
          }
        } catch (e, stack) {
          debugPrint('❌ Error parseando JSON: $e');
          debugPrint('📋 Stack: $stack');
        }
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Error 401: Token inválido o expirado');
      } else if (response.statusCode == 404) {
        debugPrint('❌ Error 404: Endpoint no encontrado');
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        debugPrint('📄 Body: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout al cargar formas de pago');
    } catch (e, stack) {
      debugPrint('💥 Error general al cargar formas de pago: $e');
      debugPrint('📋 Stack completo: $stack');
    }
  }

  Future<void> _cargarPOS(String token) async {
    debugPrint('🔄 Iniciando carga de POS...');
    debugPrint('🔑 Token: ${token.substring(0, 20)}...');

    try {
      final url = '$_baseUrl/pos/lista.php';
      debugPrint('🌐 URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);

      debugPrint('📡 POS - Status: ${response.statusCode}');
      debugPrint('📄 POS - Body completo: ${response.body}');
      debugPrint('📋 POS - Headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('📦 POS - Data parseado: $data');
          debugPrint('📦 POS - Status: ${data['status']}');
          debugPrint('📦 POS - Message: ${data['message']}');

          if (data['status'] == 'success') {
            final rawData = data['data'];
            debugPrint('📦 POS - Data raw: $rawData');
            debugPrint('📦 POS - Data tipo: ${rawData.runtimeType}');

            if (rawData is List) {
              debugPrint('✅ POS encontrados: ${rawData.length}');

              for (var i = 0; i < rawData.length; i++) {
                debugPrint('   [$i] ${rawData[i]}');
              }

              if (mounted) {
                setState(() {
                  _posList = rawData;
                  if (_posList.isNotEmpty) {
                    // --- CORRECCIÓN AQUÍ ---
                    // Usar int.tryParse para convertir el String 'ID' a un int?
                    _posSeleccionado = int.tryParse(
                      _posList[0]['ID'].toString(),
                    );
                    // -----------------------
                    debugPrint('✅ POS inicial: $_posSeleccionado');
                  }
                });
              }
            } else {
              debugPrint('❌ Data no es una lista: ${rawData.runtimeType}');
            }
          } else {
            debugPrint('⚠️ Status no exitoso: ${data['status']}');
            debugPrint('⚠️ Message: ${data['message']}');
          }
        } catch (e, stack) {
          debugPrint('❌ Error parseando JSON: $e');
          debugPrint('📋 Stack: $stack');
        }
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Error 401: Token inválido o expirado');
      } else if (response.statusCode == 404) {
        debugPrint('❌ Error 404: Endpoint no encontrado');
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        debugPrint('📄 Body: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout al cargar POS');
    } catch (e, stack) {
      debugPrint('💥 Error general al cargar POS: $e');
      debugPrint('📋 Stack completo: $stack');
    }
  }

  // 3. MODIFICAR _cargarRegalos con manejo completo de errores
  Future<void> _cargarRegalos(String token) async {
    debugPrint('🔄 Iniciando carga de regalos...');
    debugPrint('🔑 Token: ${token.substring(0, 20)}...');

    try {
      final url = '$_baseUrl/regalos/lista.php';
      debugPrint('🌐 URL: $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(_requestTimeout);

      debugPrint('📡 Regalos - Status: ${response.statusCode}');
      debugPrint('📄 Regalos - Body completo: ${response.body}');
      debugPrint('📋 Regalos - Headers: ${response.headers}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('📦 Regalos - Data parseado: $data');
          debugPrint('📦 Regalos - Status: ${data['status']}');
          debugPrint('📦 Regalos - Message: ${data['message']}');

          if (data['status'] == 'success') {
            final rawData = data['data'];
            debugPrint('📦 Regalos - Data raw: $rawData');
            debugPrint('📦 Regalos - Data tipo: ${rawData.runtimeType}');

            if (rawData is List) {
              debugPrint('✅ Regalos encontrados: ${rawData.length}');

              for (var i = 0; i < rawData.length; i++) {
                debugPrint('   [$i] ${rawData[i]}');
              }

              if (mounted) {
                setState(() {
                  _regalos = rawData;
                });
              }
            } else {
              debugPrint('❌ Data no es una lista: ${rawData.runtimeType}');
            }
          } else {
            debugPrint('⚠️ Status no exitoso: ${data['status']}');
            debugPrint('⚠️ Message: ${data['message']}');
          }
        } catch (e, stack) {
          debugPrint('❌ Error parseando JSON: $e');
          debugPrint('📋 Stack: $stack');
        }
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Error 401: Token inválido o expirado');
      } else if (response.statusCode == 404) {
        debugPrint('❌ Error 404: Endpoint no encontrado');
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        debugPrint('📄 Body: ${response.body}');
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout al cargar regalos');
    } catch (e, stack) {
      debugPrint('💥 Error general al cargar regalos: $e');
      debugPrint('📋 Stack completo: $stack');
    }
  }

  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();
    if (documento.length < 8) return;

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

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/clientes/buscar.php?documento=$documento'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final cliente = data['data'];
          if (mounted) {
            setState(() {
              _nombreClienteController.text = cliente['NOM_CLIENTE'] ?? '';
              _fuenteCliente = data['source'] ?? '';
            });
          }
        } else if (data['status'] == 'not_found') {
          if (mounted) {
            _mostrarFormularioManual();
          }
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showMessage('Tiempo de espera agotado al buscar cliente');
      }
    } catch (e) {
      _error = 'Error al buscar cliente';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Función para seleccionar imagen
  // Función para seleccionar imagen
  Future<void> _pickImage() async {
    if (_selectedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes subir un máximo de 4 fotos.'),
        ),
      );
      return;
    }

    // Mostrar diálogo para elegir entre cámara o galería
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar origen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    // Si el usuario canceló, salir
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85, // Opcional: calidad inicial
      maxWidth: 1920, // Opcional: ancho máximo
      maxHeight: 1080, // Opcional: alto máximo
    );

    if (pickedFile != null) {
      // Redimensionar y comprimir la imagen
      File? compressedImage = await _compressImage(File(pickedFile.path));

      if (compressedImage != null) {
        setState(() {
          _selectedImages.add(compressedImage);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo comprimir la imagen.')),
          );
        }
      }
    }
  }

  Future<File?> _compressImage(File file) async {
    final targetSizeKB = 200; // KB
    final targetSize = targetSizeKB * 1024; // Bytes

    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    // CORRECCIÓN: Convertir List<int> a Uint8List
    List<int> imageBytes = await file.readAsBytes();
    final img.Image? originalImage = img.decodeImage(
      Uint8List.fromList(imageBytes),
    );

    if (originalImage == null) {
      debugPrint('❌ No se pudo decodificar la imagen original.');
      return null;
    }

    int originalWidth = originalImage.width;
    int originalHeight = originalImage.height;

    for (int quality = 90; quality >= 20; quality -= 10) {
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: (originalWidth * 0.8).toInt(),
        minHeight: (originalHeight * 0.8).toInt(),
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        // CONVERSIÓN CRÍTICA: Convertir XFile a File
        File compressedFile = File(result.path);

        // Verificar el tamaño del archivo comprimido
        int compressedLength = await compressedFile.length();
        debugPrint(
          'Imagen comprimida a calidad $quality. Tamaño: ${compressedLength ~/ 1024} KB',
        );

        if (compressedLength <= targetSize || quality == 20) {
          // Si ya está dentro del tamaño deseado o hemos llegado a la calidad mínima
          return compressedFile;
        }
      }
    }
    return null;
  }

  // Función para subir una foto individual a la API
  Future<bool> _uploadPhotos(String token, int idCab) async {
    if (_selectedImages.isEmpty) {
      debugPrint('No hay fotos para subir.');
      return true;
    }

    debugPrint(
      '🚀 Iniciando subida de ${_selectedImages.length} fotos para ID_CAB: $idCab',
    );

    final url = '$_baseUrl/envios/subir_fotos.php';
    bool todasSubidas = true;

    for (int i = 0; i < _selectedImages.length; i++) {
      final File imageFile = _selectedImages[i];
      final int numeroFoto = i + 1;

      try {
        final request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['ID_CAB'] = idCab.toString();
        request.fields['numero_foto'] = numeroFoto.toString();

        var decodedCompressedImage = await decodeImageFromList(
          imageFile.readAsBytesSync(),
        );
        String resolucion =
            '${decodedCompressedImage.width}x${decodedCompressedImage.height}';

        request.fields['resolucion'] = resolucion;
        request.fields['peso_kb'] = (await imageFile.length() / 1024)
            .round()
            .toString();

        request.files.add(
          await http.MultipartFile.fromPath(
            'foto',
            imageFile.path,
            filename: 'foto_${idCab}_$numeroFoto.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );

        debugPrint('📡 Subiendo foto $numeroFoto para ID_CAB $idCab...');

        final response = await request.send().timeout(
          const Duration(seconds: 30),
        );

        final responseBody = await response.stream.bytesToString();

        debugPrint(
          '📄 Respuesta API para foto $numeroFoto: Status ${response.statusCode}, Body: $responseBody',
        );

        if (response.statusCode == 200) {
          final apiResponse = jsonDecode(responseBody);
          if (apiResponse['status'] == 'success') {
            debugPrint('✅ Foto $numeroFoto subida con éxito.');
          } else {
            debugPrint(
              '❌ Error al subir foto $numeroFoto: ${apiResponse['message']}',
            );
            todasSubidas = false;
          }
        } else {
          debugPrint(
            '❌ Error HTTP al subir foto $numeroFoto: ${response.statusCode} - $responseBody',
          );
          todasSubidas = false;
        }
      } on TimeoutException {
        debugPrint('⏱️ Timeout al subir foto $numeroFoto');
        todasSubidas = false;
      } catch (e, stack) {
        debugPrint('💥 Error al subir foto $numeroFoto: $e');
        debugPrint('📋 Stack completo al subir foto: $stack');
        todasSubidas = false;
      }
    }

    return todasSubidas;
  }

  void _mostrarFormularioManual() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cliente no encontrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nombreClienteController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Cliente *',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ubigeoController,
                decoration: InputDecoration(
                  labelText: 'Ubigeo (opcional)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _buscarUbigeo(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _buscarUbigeo() async {
    final termino = _ubigeoController.text.trim();
    if (termino.length < 3) {
      _showMessage('Ingrese al menos 3 caracteres');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ubigeo/buscar.php?q=$termino'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_requestTimeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final rawData = data['data'];
          if (rawData is List && rawData.isNotEmpty) {
            final List<Map<String, dynamic>> ubigeosValidos = rawData
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            if (ubigeosValidos.isNotEmpty) {
              setState(() => _isLoading = false);
              await _mostrarDialogoUbigeo(ubigeosValidos);
              return;
            }
          }
          _showMessage('No se encontraron ubigeos');
        } else {
          _showMessage(data['message'] ?? 'Error en búsqueda');
        }
      } else {
        _showMessage('Error del servidor: ${response.statusCode}');
      }
    } on TimeoutException {
      _showMessage('Tiempo de espera agotado');
    } catch (e) {
      _showMessage('Error de conexión');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _mostrarDialogoUbigeo(List<Map<String, dynamic>> ubigeos) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Seleccionar Ubigeo (${ubigeos.length} resultados)'),
          content: SizedBox(
            width: double.maxFinite,
            height: math.min(400.0, (ubigeos.length * 60).toDouble()),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ubigeos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ubigeo = ubigeos[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    ubigeo['DESCRIPCION'] ?? '',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      setState(() {
                        _ubigeoController.text = ubigeo['UBIGEO_CODIGO'] ?? '';
                        _descripcionUbigeo = ubigeo['DESCRIPCION'] ?? '';
                      });
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<Map<String, dynamic>?> _buscarProducto(String codigo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (!mounted) return null;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
      return null;
    }

    try {
      final codigoLimpio = codigo.replaceAll(' ', '').trim().toUpperCase();

      if (codigoLimpio.isEmpty) {
        debugPrint('❌ [BUSCAR] Código vacío después de sanitizar');
        if (mounted) {
          _showMessage('Código de producto inválido');
        }
        return null;
      }

      final url =
          '$_baseUrl/productos/buscar_por_codigo.php?codigo=${Uri.encodeComponent(codigoLimpio)}';

      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 [BUSCAR PRODUCTO]');
      debugPrint('   Código original: "$codigo"');
      debugPrint('   Código limpio: "$codigoLimpio"');
      debugPrint('   Longitud: ${codigoLimpio.length} caracteres');
      debugPrint('   URL: $url');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 Status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          debugPrint('✅ Producto encontrado:');
          debugPrint('   Código: ${data['data']['CODIGO']}');
          debugPrint('   Descripción: ${data['data']['DESCRIPCION_EQUIPO']}');
          debugPrint('   Precio: ${data['data']['PRECIO']}');
          return data['data'];
        } else {
          debugPrint(
            '⚠️ Status no exitoso: ${data['message'] ?? data['status']}',
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint('❌ Producto no encontrado (404)');
        if (mounted) {
          _showMessage('Producto con código "$codigoLimpio" no existe');
        }
        return null;
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) {
        _showMessage('Tiempo de espera agotado al buscar producto');
      }
      debugPrint('⏱️ Timeout en búsqueda de producto');
    } catch (e, stack) {
      debugPrint('💥 Error en _buscarProducto: $e');
      debugPrint('Stack trace: $stack');
    }

    return null;
  }

  Future<void> _agregarComponente() async {
    debugPrint('🔍 [TRACE] Iniciando _agregarComponente()');

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

    try {
      await _cargarCategorias(token, tipo: _tipoProducto);

      if (!mounted) return;

      if (_categorias.isEmpty) {
        _showMessage('No hay categorías disponibles para componentes');
        return;
      }

      final selectedCategoria = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Seleccionar Categoría (Componentes)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  final categoria = _categorias[index];
                  final nombre =
                      categoria['CATEGORIA']?.toString() ?? 'Sin nombre';

                  return ListTile(
                    title: Text(nombre),
                    subtitle: Text('ID: ${categoria['ID']}'),
                    onTap: () => Navigator.pop(context, categoria),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (selectedCategoria == null) return;

      debugPrint('✅ [TRACE] Categoría: ${selectedCategoria['CATEGORIA']}');

      final precio = await _ingresarPrecio(
        selectedCategoria['CATEGORIA']?.toString() ?? 'Componente',
      );

      if (!mounted) return;
      if (precio == null || precio <= 0) return;

      debugPrint('✅ [TRACE] Precio ingresado: $precio');
      debugPrint('🔍 [TRACE] Iniciando búsqueda en PrestaShop...');

      final componentes = await _buscarComponentesPrestaShop(
        selectedCategoria['ID'],
        precio,
        token,
      );

      if (!mounted) return;

      debugPrint('📊 [TRACE] Resultado: ${componentes?.length ?? "null"}');

      if (componentes == null || componentes.isEmpty) {
        return;
      }

      Map<String, dynamic>? componenteSeleccionado;

      if (componentes.length == 1) {
        componenteSeleccionado = componentes[0];
      } else {
        componenteSeleccionado = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Seleccionar (${componentes.length})'),
              content: SizedBox(
                width: double.maxFinite,
                height: math.min(400.0, componentes.length * 70.0),
                child: ListView.builder(
                  itemCount: componentes.length,
                  itemBuilder: (context, index) {
                    final comp = componentes[index];
                    return ListTile(
                      title: Text(comp['nombre'] ?? 'Sin nombre'),
                      onTap: () => Navigator.pop(context, comp),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      }

      if (!mounted) return;
      if (componenteSeleccionado == null) return;

      // NUEVO: Ingresar cantidad
      final cantidad = await _ingresarCantidad(
        componenteSeleccionado['nombre'] ?? 'Componente',
      );

      if (!mounted) return;

      if (cantidad == null || cantidad <= 0) {
        debugPrint('⚠️ [TRACE] Cantidad inválida o cancelada');
        return;
      }

      setState(() {
        _equiposSeleccionados.add({
          'codigo': 'PS-${componenteSeleccionado!['id']}',
          'descripcion': componenteSeleccionado['nombre'] ?? 'Sin descripción',
          'precio_original': precio,
          'precio_real_venta': precio,
          'precio_real_controller': TextEditingController(
            text: _formatPrecio(precio),
          ),
          'cantidad': cantidad, // NUEVO CAMPO
        });
        _calcularResumen();
      });

      _showMessage('✅ Componente agregado');
      debugPrint('✅ [TRACE] Agregado exitosamente con cantidad: $cantidad');
    } catch (e, stack) {
      debugPrint('💥 [ERROR] _agregarComponente: $e');
      debugPrint('📋 Stack: $stack');
      if (mounted) {
        _showMessage('Error al agregar componente');
      }
    }
  }

  Future<List<Map<String, dynamic>>?> _buscarComponentesPrestaShop(
    dynamic categoriaId,
    double precio,
    String token,
  ) async {
    try {
      final catId = int.parse(categoriaId.toString());
      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 [PS] Cat: $catId, Precio: $precio');

      final url = '$_baseUrl/componentes/buscar.php';

      debugPrint('🌐 [PS] POST a: $url');

      final body = jsonEncode({'categoria': catId, 'precio': precio});

      debugPrint('📤 [PS] Body: $body');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('📡 [PS] Status: ${response.statusCode}');
      debugPrint(
        '📄 [PS] Body: ${response.body.substring(0, math.min(200, response.body.length))}',
      );

      if (response.statusCode != 200) {
        if (mounted) _showMessage('Error del servidor: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'success') {
        if (mounted) _showMessage(data['message'] ?? 'Error');
        return null;
      }

      final List<dynamic> rawData = data['data'] ?? [];
      final List<Map<String, dynamic>> componentes = [];

      for (var item in rawData) {
        if (item is Map) {
          componentes.add({
            'id': item['id']?.toString() ?? '',
            'nombre': item['nombre']?.toString() ?? 'Sin nombre',
            'precio': _parsePrecio(item['precio']),
          });
        }
      }

      debugPrint('✅ [PS] Encontrados: ${componentes.length}');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return componentes;
    } on FormatException catch (e) {
      debugPrint('❌ [PS] Error convirtiendo categoriaId: $e');
      if (mounted) _showMessage('Error: ID de categoría inválido');
      return null;
    } on TimeoutException {
      debugPrint('⏱️ [PS] TIMEOUT');
      if (mounted) _showMessage('Tiempo agotado');
      return null;
    } catch (e, stack) {
      debugPrint('💥 [PS] ERROR: $e');
      debugPrint('📋 Stack: $stack');
      if (mounted) _showMessage('Error de conexión');
      return null;
    }
  }

  Future<void> _agregarRegalo() async {
    if (_regalos.isEmpty) {
      _showMessage('No hay regalos disponibles');
      return;
    }
    final selectedRegalo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Regalo'),
          content: SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: _regalos.length,
              itemBuilder: (context, index) {
                final regalo = _regalos[index];
                return ListTile(
                  title: Text(regalo['DESCRIPCION']),
                  subtitle: Text(
                    'Precio: S/ ${_formatPrecio(regalo['PRECIO'])}',
                  ),
                  onTap: () {
                    Navigator.pop(context, regalo);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
    if (selectedRegalo != null) {
      final cantidad = await _ingresarCantidad(selectedRegalo['DESCRIPCION']);
      if (cantidad != null) {
        setState(() {
          _regalosSeleccionados.add({
            'codigo': selectedRegalo['CODIGO'],
            'descripcion': selectedRegalo['DESCRIPCION'],
            'precio': _parsePrecio(selectedRegalo['PRECIO']),
            'cantidad': cantidad,
          });
          // Regalos no afectan el resumen de costos de venta principal.
        });
      }
    }
  }

  Future<int?> _ingresarCantidad(String descripcion) async {
    final controller = TextEditingController();
    final resultado = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Cantidad para $descripcion'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              hintText: 'Ej: 2',
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final cantidad = int.tryParse(value.trim());
              if (cantidad != null && cantidad > 0) {
                Navigator.of(dialogContext).pop(cantidad);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(null);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value > 0) {
                  Navigator.of(dialogContext).pop(value);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese una cantidad válida mayor a 0'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 200));
    controller.dispose();

    return resultado;
  }

  void _calcularResumen() {
    if (!mounted) return;

    double sumPrecioOriginalDB = 0.0;
    double sumPrecioRealVenta = 0.0;

    for (var equipo in _equiposSeleccionados) {
      final int cantidad = equipo['cantidad'] ?? 1; // Obtener cantidad

      // Sumar precio original * cantidad
      sumPrecioOriginalDB += _parsePrecio(equipo['precio_original']) * cantidad;

      // Asegurarse de que el 'precio_real_venta' se actualice desde el controller si existe
      final controller =
          equipo['precio_real_controller'] as TextEditingController?;
      if (controller != null) {
        final realPrice = _parsePrecio(controller.text);
        equipo['precio_real_venta'] =
            realPrice; // Actualizar el valor en el mapa
        sumPrecioRealVenta += realPrice * cantidad; // Multiplicar por cantidad
      } else {
        sumPrecioRealVenta +=
            _parsePrecio(equipo['precio_real_venta']) * cantidad;
      }
    }

    _totalEquiposComponentes = sumPrecioRealVenta;

    final double costoEnvio = _parsePrecio(_envioController.text);
    final double adelanto = _parsePrecio(_adelantoController.text);

    double comision = 0.0;
    if (_tipoComisionSeleccionada == TipoComision.porcentaje) {
      final double comisionPct = _parsePrecio(_comisionPctController.text);
      comision = _totalEquiposComponentes * (comisionPct / 100);
    } else if (_tipoComisionSeleccionada == TipoComision.importe) {
      comision = _parsePrecio(_comisionImporteController.text);
    }

    // Subtotal = Total equipos/componentes (precio real * cantidad) + Costo envío + Comisión
    final double currentSubtotalVenta =
        _totalEquiposComponentes + costoEnvio + comision;

    final double currentSaldoPendiente = currentSubtotalVenta - adelanto;

    final bool currentAdelantoInvalido = adelanto > currentSubtotalVenta;

    // Cálculo del descuento
    _descuentoCalculado = sumPrecioOriginalDB - sumPrecioRealVenta;
    if (_descuentoCalculado < 0) _descuentoCalculado = 0.0;

    setState(() {
      _comisionCalculada = comision;
      _subtotalVenta = currentSubtotalVenta;
      _saldoPendiente = currentSaldoPendiente;
      _adelantoInvalido = currentAdelantoInvalido;
      // Actualizar el controlador de precio total de equipos
      _precioTotalController.text = _formatPrecio(_totalEquiposComponentes);
    });

    debugPrint('💰 Resumen calculado:');
    debugPrint('   Total Original DB: ${_formatPrecio(sumPrecioOriginalDB)}');
    debugPrint('   Total Real Venta: ${_formatPrecio(sumPrecioRealVenta)}');
    debugPrint('   Descuento: ${_formatPrecio(_descuentoCalculado)}');
    debugPrint('   Subtotal: ${_formatPrecio(_subtotalVenta)}');
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    debugPrint(
      '🔐 [TOKEN] Recuperado: ${token?.isNotEmpty == true ? "Sí (${token!.length})" : "No"}',
    );
    return token;
  }

  Future<void> _crearVenta() async {
    if (_isLoading) return;

    final documento = _documentoController.text.trim();
    final nombreCliente = _nombreClienteController.text.trim();
    final telefono = _telefonoController.text.trim();

    // Validación según los nuevos requisitos
    if (documento.isEmpty ||
        nombreCliente.isEmpty ||
        _equiposSeleccionados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete todos los campos requeridos (Documento, Cliente, Equipos)',
            ),
          ),
        );
      }
      return;
    }

    if (_adelantoInvalido) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El adelanto no puede ser mayor al subtotal de la venta.',
            ),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final vendedorId = prefs.getString('vendedor_id');

    // ============================================================================
    // LOGS DETALLADOS DE DEBUG
    // ============================================================================
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 DEBUG CREAR VENTA');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📦 Datos de SharedPreferences:');
    debugPrint('   Token existe: ${token != null}');
    debugPrint('   Token length: ${token?.length ?? 0}');
    debugPrint(
      '   Token primeros 30 chars: ${token?.substring(0, token.length > 30 ? 30 : token.length) ?? "NULL"}',
    );
    debugPrint('   Vendedor ID: $vendedorId');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📋 Datos de venta:');
    debugPrint('   Cliente: $nombreCliente');
    debugPrint('   Documento: $documento');
    debugPrint('   Equipos: ${_equiposSeleccionados.length}');
    debugPrint('   Total: $_subtotalVenta');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (token == null || token.isEmpty) {
      debugPrint('❌ ERROR: Token no encontrado en SharedPreferences');
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sesión Expirada'),
          content: const Text(
            'Su sesión ha expirado. Por favor, inicie sesión nuevamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (vendedorId == null || vendedorId.isEmpty) {
      debugPrint('❌ ERROR: vendedor_id no encontrado');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: No se encontró ID de vendedor. Inicie sesión nuevamente.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    http.Response? response; // DECLARAR AQUÍ FUERA DEL TRY
    int statusCode = 0;

    try {
      // Preparar datos para enviar
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception('Token no disponible en el momento de la solicitud');
      }
      final ventaData = {
        'vendedor_id': prefs.getString('vendedor_id'),
        'cliente': nombreCliente,
        'documento': documento,
        'telefono': telefono,
        'direccion': _direccionController.text.trim(),
        'ubigeo': _ubigeoController.text.trim(),
        'ubigeo_descripcion': _descripcionUbigeo,
        'equipos': _equiposSeleccionados.map((equipo) {
          return {
            'codigo': equipo['codigo'],
            'descripcion': equipo['descripcion'],
            'precio_original': equipo['precio_original'],
            'precio_venta_real': equipo['precio_real_venta'],
            'cantidad': equipo['cantidad'] ?? 1,
          };
        }).toList(),
        'precio_total': _totalEquiposComponentes,
        'envio': _parsePrecio(_envioController.text),
        'comision_porcentaje':
            _tipoComisionSeleccionada == TipoComision.porcentaje
            ? _parsePrecio(_comisionPctController.text)
            : 0.0,
        'comision_importe': _tipoComisionSeleccionada == TipoComision.importe
            ? _parsePrecio(_comisionImporteController.text)
            : 0.0,
        'total': _subtotalVenta,
        'adelanto': _parsePrecio(_adelantoController.text),
        'saldo': _saldoPendiente,
        'observacion': _observacionController.text.trim(),
        'cambios': _cambioController.text.trim(),
        'forma_pago_adelanto': _formaPagoAdelantoSeleccionada,
        'forma_pago_saldo': _formaPagoSaldoSeleccionada,
        'pos': _posSeleccionado,
      };

      debugPrint('📤 Enviando venta a: $_baseUrl/ventas/crear.php');
      debugPrint('🔐 Token presente: ${token.length} caracteres');
      debugPrint(
        '🔑 Header Authorization: Bearer ${token.substring(0, 20)}...',
      );
      debugPrint(
        '📦 Datos JSON: ${jsonEncode(ventaData).substring(0, 200)}...',
      );

      response = await http
          .post(
            Uri.parse('$_baseUrl/ventas/crear.php'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(ventaData),
          )
          .timeout(const Duration(seconds: 30));

      statusCode = response.statusCode;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 RESPUESTA DEL SERVIDOR');
      debugPrint('   Status Code: $statusCode');
      debugPrint('   Headers: ${response.headers}');
      debugPrint('   Body: ${response.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (statusCode == 200 || statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final idCab = data['data']['id_cab'];
          debugPrint('✅ Venta creada con ID_CAB: $idCab');

          // Subir fotos si existen
          bool fotosSubidas = true;
          if (_selectedImages.isNotEmpty) {
            debugPrint(
              '📸 Iniciando subida de ${_selectedImages.length} fotos...',
            );
            fotosSubidas = await _uploadPhotos(token, idCab);

            if (!fotosSubidas) {
              debugPrint('⚠️ Algunas fotos no se pudieron subir');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Venta creada pero algunas fotos no se subieron',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } else {
              debugPrint('✅ Todas las fotos subidas exitosamente');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  fotosSubidas && _selectedImages.isNotEmpty
                      ? 'Venta creada exitosamente con fotos'
                      : 'Venta creada exitosamente',
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop(true);
          }
        } else {
          _error = data['message'] ?? 'Error al crear venta';
          debugPrint('❌ Error del servidor: $_error');
        }
      } else if (statusCode == 401) {
        // ERROR 401 - TOKEN INVÁLIDO
        debugPrint('❌ ERROR 401: Token inválido o expirado');

        try {
          final data = jsonDecode(response.body);
          _error = data['message'] ?? 'Token inválido o expirado';
        } catch (e) {
          _error = 'Token inválido o expirado';
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sesión Expirada'),
              content: Text(_error),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Iniciar Sesión'),
                ),
              ],
            ),
          );
        }
      } else {
        _error = 'Error del servidor: $statusCode';
        debugPrint('❌ HTTP Error: $_error');
        debugPrint('📄 Body: ${response.body}');
      }
    } on TimeoutException {
      _error = 'Tiempo de espera agotado. Intente nuevamente.';
      debugPrint('⏱️ Timeout en crear venta');
    } catch (e, stack) {
      _error = 'No se pudo conectar al servidor';
      debugPrint('💥 Error en _crearVenta: $e');
      debugPrint('📋 Stack: $stack');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Mostrar error si existe (y no es 401 que ya tiene su propio diálogo)
        if (_error.isNotEmpty && statusCode != 401) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error al crear venta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Desea intentar nuevamente?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _crearVenta();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitialData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nueva Venta'),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Cargando datos iniciales...',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ..._loadingStatus.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        e.value ? Icons.check_circle : Icons.hourglass_empty,
                        color: e.value ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getLabelForKey(e.key),
                        style: TextStyle(
                          color: e.value ? Colors.green : Colors.grey,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Venta'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          if (_loadingError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadingError!,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _loadingError = null;
                        _isLoadingInitialData = true;
                      });
                      _cargarDatosIniciales();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _documentoController,
                    focusNode: _documentoFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Documento del Cliente *',
                      border: const OutlineInputBorder(),
                      // ✅ CAMBIADO: Botón de búsqueda en lugar de automático
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_nombreClienteController.text.isNotEmpty)
                            const Icon(Icons.check_circle, color: Colors.green)
                          else
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                if (_documentoController.text.trim().length >=
                                    8) {
                                  _buscarCliente();
                                } else {
                                  _showMessage('Ingrese al menos 8 dígitos');
                                }
                              },
                              tooltip: 'Buscar cliente',
                            ),
                        ],
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    // ✅ ELIMINADO: onChanged que buscaba automáticamente
                    onChanged: (value) {
                      // Solo limpiar el nombre si se borra el documento
                      if (value.length < 8) {
                        setState(() {
                          _nombreClienteController.text = '';
                          _ubigeoController.text = '';
                        });
                      }
                    },
                    onTap: () {
                      _documentoController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _documentoController.text.length,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_nombreClienteController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Cliente: ${_nombreClienteController.text}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nombreClienteController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Cliente *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_ubigeoController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Ubigeo: $_descripcionUbigeo',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  TextField(
                    controller: _ubigeoController,
                    decoration: InputDecoration(
                      labelText: 'Código de Ubigeo',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _buscarUbigeo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _telefonoController,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _direccionController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Equipos (${_equiposSeleccionados.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipoProducto,
                          items: const [
                            DropdownMenuItem(
                              value: 'equipo',
                              child: Text('Equipo'),
                            ),
                            DropdownMenuItem(
                              value: 'componente',
                              child: Text('Componente'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              debugPrint(
                                '🔄 [DROPDOWN] Cambiando tipo a: $value',
                              );
                              setState(() {
                                _tipoProducto = value;
                                _categorias = [];
                              });
                              debugPrint(
                                '✅ [DROPDOWN] Categorías limpiadas. Tipo actual: $_tipoProducto',
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : (_tipoProducto == 'equipo'
                                ? _agregarEquipo
                                : _agregarComponente),
                      icon: Icon(
                        _tipoProducto == 'equipo'
                            ? Icons.devices
                            : Icons.memory,
                      ),
                      label: Text(
                        _tipoProducto == 'equipo'
                            ? 'Agregar Equipo'
                            : 'Agregar Componente',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._equiposSeleccionados.asMap().entries.map((entry) {
                    final index = entry.key;
                    final equipo = entry.value;
                    final TextEditingController precioRealController =
                        equipo['precio_real_controller'];
                    final int cantidad = equipo['cantidad'] ?? 1;
                    final double precioUnitario = _parsePrecio(
                      equipo['precio_real_venta'],
                    );
                    final double subtotalItem = precioUnitario * cantidad;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        equipo['descripcion'] ??
                                            'Sin descripción',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Código: ${equipo['codigo'] ?? 'N/A'} | Cant: $cantidad',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      // NUEVO: Mostrar subtotal del item
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Subtotal: S/ ${_formatPrecio(subtotalItem)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      (equipo['precio_real_controller']
                                              as TextEditingController)
                                          .dispose();
                                      _equiposSeleccionados.removeAt(index);
                                      _calcularResumen();
                                    });
                                    _showMessage('Producto eliminado');
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Precio DB: S/ ${_formatPrecio(equipo['precio_original'])}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cantidad: $cantidad',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: precioRealController,
                                    decoration: const InputDecoration(
                                      labelText: 'Precio Unit. Venta',
                                      prefixText: 'S/ ',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (value) {
                                      equipo['precio_real_venta'] =
                                          _parsePrecio(value);
                                      _calcularResumen();
                                    },
                                    onTap: () {
                                      precioRealController
                                          .selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            precioRealController.text.length,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _precioTotalController,
                    decoration: const InputDecoration(
                      labelText: 'Total venta Real',
                      prefixIcon: Icon(Icons.calculate),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled:
                        false, // Ahora se actualizará desde _calcularResumen
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _envioController,
                    focusNode: _envioFocusNode, // Asociar FocusNode
                    decoration: const InputDecoration(
                      labelText: 'Costo de Envío',
                      prefixIcon: Icon(Icons.local_shipping),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) =>
                        _calcularResumen(), // Agregado listener
                    onTap: () {
                      // Seleccionar todo el texto al tocar
                      _envioController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _envioController.text.length,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Selector de tipo de comisión
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tipo de Comisión',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButtonFormField<TipoComision>(
                        initialValue: _tipoComisionSeleccionada,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: TipoComision.ninguna,
                            child: Text('Sin Comisión'),
                          ),
                          DropdownMenuItem(
                            value: TipoComision.porcentaje,
                            child: Text('Porcentaje (%)'),
                          ),
                          DropdownMenuItem(
                            value: TipoComision.importe,
                            child: Text('Importe (S/)'),
                          ),
                        ],
                        onChanged: (TipoComision? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _tipoComisionSeleccionada = newValue;
                              _calcularResumen(); // Recalcular al cambiar el tipo
                            });
                          }
                        },
                      ),
                      if (_tipoComisionSeleccionada == TipoComision.porcentaje)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextField(
                            controller: _comisionPctController,
                            focusNode:
                                _comisionPctFocusNode, // Asociar FocusNode
                            decoration: const InputDecoration(
                              labelText: 'Comisión (%)',
                              suffixText: '%',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) =>
                                _calcularResumen(), // Listener para el resumen
                            onTap: () {
                              // Seleccionar todo el texto al tocar
                              _comisionPctController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset:
                                    _comisionPctController.text.length,
                              );
                            },
                          ),
                        ),
                      if (_tipoComisionSeleccionada == TipoComision.importe)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: TextField(
                            controller: _comisionImporteController,
                            focusNode:
                                _comisionImporteFocusNode, // Asociar FocusNode
                            decoration: const InputDecoration(
                              labelText: 'Comisión (S/)',
                              prefixText: 'S/ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) =>
                                _calcularResumen(), // Listener para el resumen
                            onTap: () {
                              // Seleccionar todo el texto al tocar
                              _comisionImporteController.selection =
                                  TextSelection(
                                    baseOffset: 0,
                                    extentOffset:
                                        _comisionImporteController.text.length,
                                  );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _adelantoController,
                    focusNode: _adelantoFocusNode, // Asociar FocusNode
                    decoration: const InputDecoration(
                      labelText: 'Adelanto',
                      prefixIcon: Icon(Icons.payment),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) =>
                        _calcularResumen(), // Listener para el resumen
                    onTap: () {
                      _adelantoController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _adelantoController.text.length,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Forma de Pago (Adelanto)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Builder(
                    builder: (context) {
                      debugPrint('🎨 Renderizando Forma Pago Adelanto');
                      debugPrint('   Lista: ${_formasPago.length} items');
                      debugPrint(
                        '   Seleccionado: $_formaPagoAdelantoSeleccionada',
                      );

                      return DropdownButtonFormField<int>(
                        initialValue: _formaPagoAdelantoSeleccionada,
                        isExpanded:
                            true, // ✅ AGREGADO: Permite expansión completa
                        items: _formasPago.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Cargando...'),
                                ),
                              ]
                            : _formasPago.map((fp) {
                                debugPrint(
                                  '   Item: ID=${fp['ID']}, Nombre=${fp['FORMAP']}',
                                );

                                // ✅ NUEVO: Dividir texto en 2 columnas si es muy largo
                                final nombreCompleto =
                                    fp['FORMAP']?.toString() ?? 'Sin nombre';

                                return DropdownMenuItem<int>(
                                  value: int.tryParse(fp['ID'].toString()),
                                  child: Row(
                                    children: [
                                      // Columna 1: ID
                                      Container(
                                        width: 40,
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Text(
                                          '${fp['ID']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      // Columna 2: Nombre (con wrap)
                                      Expanded(
                                        child: Text(
                                          nombreCompleto,
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        onChanged: _formasPago.isEmpty
                            ? null
                            : (value) {
                                debugPrint('🔄 Cambio Adelanto: $value');
                                setState(
                                  () => _formaPagoAdelantoSeleccionada = value,
                                );
                              },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12, // ✅ AUMENTADO: Más espacio vertical
                          ),
                          isDense: false, // ✅ CAMBIADO: Permite más altura
                        ),
                        // ✅ NUEVO: Menú con ancho personalizado
                        menuMaxHeight: 300,
                        selectedItemBuilder: (BuildContext context) {
                          return _formasPago.map<Widget>((fp) {
                            final nombreCompleto =
                                fp['FORMAP']?.toString() ?? 'Sin nombre';
                            return Row(
                              children: [
                                Text(
                                  '${fp['ID']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nombreCompleto,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Forma de Pago (Saldo)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Builder(
                    builder: (context) {
                      debugPrint('🎨 Renderizando Forma Pago Saldo');
                      debugPrint('   Lista: ${_formasPago.length} items');
                      debugPrint(
                        '   Seleccionado: $_formaPagoSaldoSeleccionada',
                      );

                      return DropdownButtonFormField<int>(
                        initialValue: _formaPagoSaldoSeleccionada,
                        isExpanded: true, // ✅ AGREGADO
                        items: _formasPago.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Cargando...'),
                                ),
                              ]
                            : _formasPago.map((fp) {
                                final nombreCompleto =
                                    fp['FORMAP']?.toString() ?? 'Sin nombre';

                                return DropdownMenuItem<int>(
                                  value: int.tryParse(fp['ID'].toString()),
                                  child: Row(
                                    children: [
                                      // Columna 1: ID
                                      Container(
                                        width: 40,
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Text(
                                          '${fp['ID']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      // Columna 2: Nombre
                                      Expanded(
                                        child: Text(
                                          nombreCompleto,
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        onChanged: _formasPago.isEmpty
                            ? null
                            : (value) {
                                debugPrint('🔄 Cambio Saldo: $value');
                                setState(
                                  () => _formaPagoSaldoSeleccionada = value,
                                );
                              },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          isDense: false,
                        ),
                        menuMaxHeight: 300,
                        selectedItemBuilder: (BuildContext context) {
                          return _formasPago.map<Widget>((fp) {
                            final nombreCompleto =
                                fp['FORMAP']?.toString() ?? 'Sin nombre';
                            return Row(
                              children: [
                                Text(
                                  '${fp['ID']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nombreCompleto,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      );
                    },
                  ),

                  const Text(
                    'POS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Builder(
                    builder: (context) {
                      debugPrint('🎨 Renderizando POS');
                      debugPrint('   Lista: ${_posList.length} items');
                      debugPrint('   Seleccionado: $_posSeleccionado');

                      return DropdownButtonFormField<int>(
                        initialValue: _posSeleccionado,
                        items: _posList.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Cargando...'),
                                ),
                              ]
                            : _posList.map((pos) {
                                debugPrint(
                                  '   Item: ID=${pos['ID']}, Desc=${pos['DESCRIPCION']}',
                                );
                                return DropdownMenuItem<int>(
                                  value: int.tryParse(pos['ID'].toString()),
                                  child: Text(
                                    pos['DESCRIPCION']?.toString() ??
                                        'Sin nombre',
                                  ),
                                );
                              }).toList(),
                        onChanged: _posList.isEmpty
                            ? null
                            : (value) {
                                debugPrint('🔄 Cambio POS: $value');
                                setState(() => _posSeleccionado = value);
                              },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN REGALOS - Reemplazar desde línea ~1915
                  const Text(
                    'Regalos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _regalos.isEmpty ? null : _agregarRegalo,
                    icon: const Icon(Icons.card_giftcard),
                    label: Text(
                      _regalos.isEmpty
                          ? 'No hay regalos disponibles'
                          : 'Agregar Regalo',
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_regalosSeleccionados.isNotEmpty)
                    ..._regalosSeleccionados.map((regalo) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(
                            regalo['descripcion'] ?? 'Sin descripción',
                          ),
                          subtitle: Text(
                            'Precio: S/ ${_formatPrecio(regalo['precio'])}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cant: ${regalo['cantidad'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _regalosSeleccionados.remove(regalo);
                                  });
                                  _showMessage('Regalo eliminado');
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  if (_regalos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No hay regalos disponibles en el sistema',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _observacionController,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                    ), // Ajusta el padding según tu diseño
                    child: TextFormField(
                      controller: _cambioController,
                      decoration: const InputDecoration(
                        labelText: 'Cambio',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),

                  const SizedBox(height: 20), // Espacio entre los campos

                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 4,
                    color: _adelantoInvalido
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumen de Venta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const Divider(height: 16),
                          _buildSummaryRow(
                            'Total Venta:',
                            _formatPrecio(_totalEquiposComponentes),
                          ),
                          _buildSummaryRow(
                            'Costo de Envío:',
                            _formatPrecio(_parsePrecio(_envioController.text)),
                          ),
                          _buildSummaryRow(
                            'Comisión (${_tipoComisionSeleccionada == TipoComision.porcentaje ? '${_formatPrecio(_parsePrecio(_comisionPctController.text))}%' : 'S/'}):',
                            _formatPrecio(_comisionCalculada),
                          ),
                          _buildSummaryRow(
                            'Descuento:',
                            _formatPrecio(_descuentoCalculado),
                            color: _descuentoCalculado > 0 ? Colors.red : null,
                          ), // NUEVO: Descuento
                          const Divider(height: 16),
                          _buildSummaryRow(
                            'SUBTOTAL:',
                            _formatPrecio(_subtotalVenta),
                            isBold: true,
                            color: Colors.deepPurple,
                          ),
                          _buildSummaryRow(
                            'Adelanto:',
                            _formatPrecio(
                              _parsePrecio(_adelantoController.text),
                            ),
                            color: _adelantoInvalido ? Colors.red : null,
                          ),
                          _buildSummaryRow(
                            'SALDO PENDIENTE:',
                            _formatPrecio(_saldoPendiente),
                            isBold: true,
                            color: _adelantoInvalido
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                          if (_adelantoInvalido)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '⚠️ El adelanto no puede ser mayor al subtotal de la venta.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Fin Tarjeta de Resumen
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjuntar Fotos (Máximo 4)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: _selectedImages.length < 4
                            ? _selectedImages.length + 1
                            : _selectedImages.length,
                        itemBuilder: (context, index) {
                          if (index < _selectedImages.length) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.file(
                                    _selectedImages[index],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 25,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 30,
                                      color: Colors.grey,
                                    ),
                                    Text(
                                      'Añadir',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ), // Espacio antes del botón de guardar
                  if (_error.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _adelantoInvalido)
                          ? null
                          : _crearVenta,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Creando...' : 'Crear Venta'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NUEVO: Función auxiliar para las filas de resumen
  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
          Text(
            'S/ $value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
