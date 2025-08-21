// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import 'planilla_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _load = false;
  bool _isOnline = true;
  String? _savedUsername;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadSavedUsername();
    _tryAutoLogin();
    
    // Escuchar cambios de conectividad
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivity != ConnectivityResult.none;
    });
  }

  Future<void> _loadSavedUsername() async {
    final username = await AuthService.savedUsername;
    setState(() {
      _savedUsername = username;
      if (username != null) {
        _user.text = username;
      }
    });
  }

  Future<void> _tryAutoLogin() async {
    final result = await AuthService.autoLogin();
    if (result['success'] == true) {
      _showMessage(result['message'], isError: false);
      _navigateToHome();
    }
  }

  Future<void> _submit() async {
    if (_user.text.trim().isEmpty || _pass.text.trim().isEmpty) {
      _showMessage('Por favor ingresa usuario y contraseña', isError: true);
      return;
    }

    setState(() => _load = true);
    
    try {
      final result = await AuthService.login(_user.text.trim(), _pass.text.trim());
      
      if (result['success'] == true) {
        _showMessage(result['message'], isError: false);
        _navigateToHome();
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Error inesperado: $e', isError: true);
    } finally {
      setState(() => _load = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PlanillaListScreen()),
    );
  }

  Future<void> _showOfflineInfo() async {
    final canOffline = await AuthService.canLoginOffline();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modo Offline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: Sin conexión a internet'),
            SizedBox(height: 8),
            Text(canOffline 
              ? 'Puedes iniciar sesión con las credenciales guardadas anteriormente.'
              : 'No hay credenciales guardadas. Necesitas conectarte a internet al menos una vez.'),
            if (_savedUsername != null) ...[
              SizedBox(height: 8),
              Text('Usuario guardado: $_savedUsername'),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Veterinario'),
        actions: [
          // Indicador de conexión
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showOfflineInfo,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: _isOnline ? Colors.green : Colors.orange,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: _isOnline ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    body: Padding(
      padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mensaje informativo si está offline
            if (!_isOnline)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Modo Offline',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      _savedUsername != null 
                        ? "✅ Puedes iniciar sesión con las credenciales guardadas"
                        : "❌ No hay credenciales guardadas. Conéctate a internet primero.",
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            
            TextField(
              controller: _user,
              decoration: InputDecoration(
                labelText: 'Usuario',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _pass,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 24),
            
        ElevatedButton(
          onPressed: _load ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _load 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Iniciando sesión...'),
                    ],
                  )
                : Text(
                    'Ingresar',
                    style: TextStyle(fontSize: 16),
                  ),
            ),
            
            // Información adicional
            if (_savedUsername != null) ...[
              SizedBox(height: 16),
              Text(
                'Usuario guardado: $_savedUsername',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
            
            // Credenciales por defecto
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credenciales por defecto:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Usuario: admin\nContraseña: admin',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
