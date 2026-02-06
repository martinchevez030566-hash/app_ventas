import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'my_sales_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  bool _obscurePassword = true; // 👈 Controla la visibilidad de la contraseña

  final String _baseUrl = 'https://sistemasmipclista.com/api_ventas/api/v1';

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Por favor, ingrese usuario y contraseña';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      debugPrint('🔐 Intentando login...');
      debugPrint('   Usuario: $usuario');
      debugPrint('   URL: $_baseUrl/auth/login.php');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login.php'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'nombre_usuario': usuario, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 Response Status: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        bool isSuccess = false;
        Map<String, dynamic>? userData;

        if (data.containsKey('success') && data['success'] == true) {
          isSuccess = true;
          userData = data;
        } else if (data.containsKey('status') && data['status'] == 'success') {
          isSuccess = true;
          userData = data['data'];
        }

        if (isSuccess && userData != null) {
          final token = userData['token']?.toString().trim() ?? '';
          String vendedorId = '';
          if (userData['vendedor_id'] != null) {
            vendedorId = userData['vendedor_id'].toString().trim();
          }
          final vendedorNombre =
              userData['vendedor_nombre']?.toString().trim() ?? '';

          if (token.isEmpty) {
            throw Exception('Token vacío recibido del servidor');
          }
          if (vendedorId.isEmpty) {
            throw Exception('vendedor_id vacío recibido del servidor');
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('vendedor_id', vendedorId);
          await prefs.setString('vendedor_nombre', vendedorNombre);

          debugPrint('✅ Login exitoso');
          debugPrint('   Token guardado: ${token.substring(0, 20)}...');
          debugPrint('   Vendedor ID: $vendedorId');
          debugPrint('   Vendedor Nombre: $vendedorNombre');

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MySalesScreen()),
            );
          }
        } else {
          final errorMsg =
              data['message']?.toString() ?? 'Credenciales inválidas';
          debugPrint('❌ Login fallido: $errorMsg');
          if (mounted) {
            setState(() {
              _error = errorMsg;
            });
          }
        }
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        try {
          final data = jsonDecode(response.body);
          final errorMsg =
              data['message']?.toString() ?? 'Error en la solicitud';
          debugPrint('❌ Error ${response.statusCode}: $errorMsg');
          if (mounted) {
            setState(() {
              _error = errorMsg;
            });
          }
        } catch (e) {
          debugPrint('❌ Error parseando respuesta de error');
          if (mounted) {
            setState(() {
              _error = 'Error del servidor: ${response.statusCode}';
            });
          }
        }
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode}');
        if (mounted) {
          setState(() {
            _error = 'Error del servidor: ${response.statusCode}';
          });
        }
      }
    } on TimeoutException {
      debugPrint('⏱️ Timeout en login');
      if (mounted) {
        setState(() {
          _error = 'Tiempo de espera agotado. Intente nuevamente.';
        });
      }
    } on FormatException catch (e) {
      debugPrint('💥 Error parseando JSON: $e');
      if (mounted) {
        setState(() {
          _error = 'Error en respuesta del servidor';
        });
      }
    } catch (e, stack) {
      debugPrint('💥 Error en login: $e');
      debugPrint('📋 Stack: $stack');
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
        title: const Text('Iniciar Sesión'),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Image.network(
                'https://sistemasmipclista.com/logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.blue,
                  );
                },
              ),
              const SizedBox(height: 40),

              // Campo Usuario
              TextField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Campo Contraseña con toggle de visibilidad
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword, // 👈 Control dinámico
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Mensaje de error
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error.isNotEmpty) const SizedBox(height: 16),

              // Botón de login
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
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
    );
  }
}
