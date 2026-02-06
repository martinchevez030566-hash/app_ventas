import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io';
// ignore: unused_import
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Importa el paquete image
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AddPaymentScreen extends StatefulWidget {
  final int ventaId;
  final double saldoActual;
  const AddPaymentScreen({
    super.key,
    required this.ventaId,
    required this.saldoActual,
  });
  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _observacionController = TextEditingController();
  final TextEditingController _excesoController = TextEditingController();
  final FocusNode _montoFocusNode = FocusNode();
  int? _formaPagoSeleccionada;
  List<dynamic> _formasPago = [];
  bool _isLoading = false;
  String _error = '';
  bool _isLoadingFormasPago = true;
  String _errorFormasPago = '';
  final List<File> _selectedImages = []; // Lista para almacenar las fotos
  final String _baseUrl = 'https://sistemasmipclista.com/api_ventas/api/v1';
  @override
  void initState() {
    super.initState();
    _cargarFormasPago();
    if (widget.saldoActual > 0) {
      _montoController.text = widget.saldoActual.toStringAsFixed(2);
    }

    _montoFocusNode.addListener(() {
      if (_montoFocusNode.hasFocus) {
        _montoController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _montoController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _observacionController.dispose();
    _excesoController.dispose();
    _montoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarFormasPago() async {
    if (!context.mounted) return;
    setState(() {
      _isLoadingFormasPago = true;
      _errorFormasPago = '';
    });

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
        Uri.parse('$_baseUrl/formas_pago/lista.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _formasPago = data['data'] ?? [];
            if (_formasPago.isNotEmpty) {
              _formaPagoSeleccionada = int.tryParse(
                _formasPago[0]['ID'].toString(),
              );
            }
          });
        } else {
          setState(() {
            _errorFormasPago =
                data['message'] ?? 'Error al cargar formas de pago.';
          });
        }
      } else {
        setState(() {
          _errorFormasPago =
              'Error del servidor al cargar formas de pago: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _errorFormasPago = 'No se pudo conectar para cargar formas de pago: $e';
      });
    } finally {
      if (!context.mounted) return;
      setState(() {
        _isLoadingFormasPago = false;
      });
    }
  }

  // Función para seleccionar imagen (copiado de new_sale_screen.dart)
  Future<void> _pickImage() async {
    if (_selectedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes subir un máximo de 4 fotos.'),
        ),
      );
      return;
    }

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

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (pickedFile != null) {
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

  // Función para comprimir imagen (copiado de new_sale_screen.dart)
  Future<File?> _compressImage(File file) async {
    const targetSizeKB = 200; // KB
    const targetSize = targetSizeKB * 1024; // Bytes

    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        File compressedFile = File(result.path);

        int compressedLength = await compressedFile.length();
        debugPrint(
          'Imagen comprimida a calidad $quality. Tamaño: ${compressedLength ~/ 1024} KB',
        );

        if (compressedLength <= targetSize || quality == 20) {
          return compressedFile;
        }
      }
    }
    return null;
  }

  // Función para subir una foto individual a la API (copiado de new_sale_screen.dart)
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

  Future<void> _registrarPago() async {
    if (_isLoading) return;
    if (widget.saldoActual <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pueden registrar pagos, el saldo es 0.'),
          ),
        );
      }
      return;
    }

    final montoStr = _montoController.text.trim();
    final excesoStr = _excesoController.text.trim();

    if (montoStr.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingrese el monto del pago')),
        );
      }
      return;
    }

    final monto = double.tryParse(montoStr);
    final exceso = double.tryParse(excesoStr) ?? 0.0;

    if (monto == null || monto <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Monto inválido')));
      }
      return;
    }

    if (_formaPagoSeleccionada == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione una forma de pago')),
        );
      }
      return;
    }

    if (monto > widget.saldoActual && (monto - widget.saldoActual) > exceso) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El monto no puede ser mayor al saldo pendiente (S/ ${widget.saldoActual.toStringAsFixed(2)}) sin cubrir la diferencia con Exceso.',
            ),
          ),
        );
      }
      return;
    }

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

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/registrar_pago.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'id_venta': widget.ventaId,
          'monto': monto,
          'forma_pago_id': _formaPagoSeleccionada,
          'observacion': _observacionController.text.trim(),
          'exceso': exceso,
        }),
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Subir fotos si existen
          bool fotosSubidas = true;
          if (_selectedImages.isNotEmpty) {
            debugPrint(
              '📸 Iniciando subida de ${_selectedImages.length} fotos para el pago...',
            );
            fotosSubidas = await _uploadPhotos(
              token,
              widget.ventaId,
            ); // Usar widget.ventaId como ID_CAB

            if (!fotosSubidas) {
              debugPrint('⚠️ Algunas fotos del pago no se pudieron subir');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pago registrado pero algunas fotos no se subieron',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } else {
              debugPrint('✅ Todas las fotos del pago subidas exitosamente');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                fotosSubidas && _selectedImages.isNotEmpty
                    ? 'Pago registrado exitosamente con fotos'
                    : 'Pago registrado exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _error = data['message'] ?? 'Error al registrar pago';
          });
        }
      } else {
        setState(() {
          _error =
              'Error del servidor: ${response.statusCode} - ${response.body}';
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'Tiempo de espera agotado al registrar pago.';
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = 'No se pudo conectar al servidor: $e';
      });
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canRegisterPayment =
        widget.saldoActual > 0 && !_isLoading && !_isLoadingFormasPago;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago Adicional'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venta ID: ${widget.ventaId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Saldo Pendiente: S/ ${widget.saldoActual.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.saldoActual > 0
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montoController,
              focusNode: _montoFocusNode,
              decoration: const InputDecoration(
                labelText: 'Monto del Pago *',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: widget.saldoActual > 0,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _excesoController,
              decoration: const InputDecoration(
                labelText: 'Exceso (opcional)',
                helperText: 'Solo si el pago es mayor al saldo',
                prefixIcon: Icon(Icons.add_circle_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: widget.saldoActual > 0,
            ),
            const SizedBox(height: 16),
            if (_isLoadingFormasPago)
              const Center(child: CircularProgressIndicator())
            else if (_errorFormasPago.isNotEmpty)
              Center(
                child: Text(
                  'Error cargando formas de pago: $_errorFormasPago',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_formasPago.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forma de Pago *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _formaPagoSeleccionada,
                    items: _formasPago.map<DropdownMenuItem<int>>((forma) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(forma['ID'].toString()),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.75,
                          child: Text(
                            forma['FORMAP']?.toString() ?? 'Sin nombre',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: widget.saldoActual > 0
                        ? (value) {
                            setState(() {
                              _formaPagoSeleccionada = value;
                            });
                          }
                        : null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'Seleccione una forma de pago' : null,
                    hint: const Text('Seleccione una forma de pago'),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 16),
                ],
              )
            else
              Center(
                child: Text(
                  widget.saldoActual > 0
                      ? 'No se encontraron formas de pago disponibles.'
                      : 'No se requieren formas de pago para saldo 0.',
                ),
              ),
            TextField(
              controller: _observacionController,
              decoration: const InputDecoration(
                labelText: 'Observación',
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: widget.saldoActual > 0,
            ),
            const SizedBox(height: 24), // Espacio adicional para las fotos
            // SECCIÓN DE ADJUNTAR FOTOS
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adjuntar Fotos (Máximo 4)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

            // FIN SECCIÓN DE ADJUNTAR FOTOS
            const SizedBox(height: 24),
            if (_error.isNotEmpty)
              Center(
                child: Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canRegisterPayment ? _registrarPago : null,
                icon: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.payment),
                label: _isLoading
                    ? const Text('Registrando...')
                    : const Text('Registrar Pago'),
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
    );
  }
}
