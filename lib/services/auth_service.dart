// lib/services/auth_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage_service.dart';
import 'api_config.dart';

class AuthService {
  static final _base = ApiConfig.root;

  /// Intenta hacer login online, si falla permite offline
  static Future<Map<String, dynamic>> login(String user, String pass) async {
    try {
      // Verificar conectividad
      final connectivity = await Connectivity().checkConnectivity();
      print('🔍 Estado de conectividad: $connectivity');
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar login online
        try {
          print('🌐 Intentando conexión a: ${_base}api-token-auth/');
          final resp = await http.post(
            Uri.parse('${_base}api-token-auth/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': user, 'password': pass}),
          ).timeout(Duration(seconds: 15));
          
          print('📡 Respuesta del servidor: ${resp.statusCode} - ${resp.body}');
          
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            final token = data['token'] as String;
            final userType = data['user_type'] ?? 'vacunador'; // Tipo de usuario del backend
            await LocalStorageService.saveToken(token);
            await LocalStorageService.saveUserData(user, pass, userType: userType);
            return {
              'success': true,
              'mode': 'online',
              'message': 'Login exitoso (online)',
              'user_type': userType
            };
          } else {
            print('❌ Error del servidor: ${resp.statusCode}');
            // Si falla online, intentar offline
            return await _tryOfflineLogin(user, pass, 'Error del servidor: ${resp.statusCode}');
          }
        } catch (e) {
          print('❌ Error de red: $e');
          // Si hay error de red, intentar offline
          return await _tryOfflineLogin(user, pass, 'Error de conexión: $e');
        }
      } else {
        print('📱 Sin conexión a internet');
        // Sin conexión, verificar offline
        return await _tryOfflineLogin(user, pass, 'Sin conexión a internet');
      }
    } catch (e) {
      print('💥 Error inesperado: $e');
      return {
        'success': false,
        'mode': 'error',
        'message': 'Error inesperado: $e'
      };
    }
  }

  /// Intenta login offline con credenciales guardadas o por defecto
  static Future<Map<String, dynamic>> _tryOfflineLogin(String user, String pass, String reason) async {
    print('🔄 Intentando login offline...');
    
    // Primero verificar credenciales guardadas
    final storedData = await LocalStorageService.getUserData();
    if (storedData != null && 
        storedData['username'] == user && 
        storedData['password'] == pass) {
      print('✅ Login offline con credenciales guardadas');
      return {
        'success': true,
        'mode': 'offline',
        'message': 'Login exitoso (modo offline)'
      };
    }
    
    // Si no hay credenciales guardadas, verificar credenciales por defecto
    if (user == 'admin' && pass == 'admin') {
      print('✅ Login offline con credenciales por defecto');
      // Guardar las credenciales por defecto para uso futuro
      await LocalStorageService.saveUserData(user, pass, userType: 'administrador');
      return {
        'success': true,
        'mode': 'offline',
        'message': 'Login exitoso (modo offline con credenciales por defecto)',
        'user_type': 'administrador'
      };
    }
    
    print('❌ Login offline fallido: $reason');
    return {
      'success': false,
      'mode': 'offline',
      'message': '$reason. Usuario: admin, Contraseña: admin'
    };
  }

  /// Verificar si hay datos guardados para login offline
  static Future<bool> canLoginOffline() async {
    final storedData = await LocalStorageService.getUserData();
    return storedData != null;
  }

  /// Auto-login si el usuario ya se autenticó anteriormente
  static Future<Map<String, dynamic>> autoLogin() async {
    final storedData = await LocalStorageService.getUserData();
    if (storedData != null) {
      final username = storedData['username'] as String;
      final password = storedData['password'] as String;
      
      // Verificar conectividad para decidir el modo
      final connectivity = await Connectivity().checkConnectivity();
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar renovar token online
        try {
          final resp = await http.post(
            Uri.parse('${_base}api-token-auth/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          ).timeout(Duration(seconds: 5));
          
          if (resp.statusCode == 200) {
            final token = json.decode(resp.body)['token'] as String;
            await LocalStorageService.saveToken(token);
            return {
              'success': true,
              'mode': 'online',
              'message': 'Sesión renovada (online)',
              'username': username
            };
          }
        } catch (e) {
          // Si falla, usar modo offline
        }
      }
      
      // Usar modo offline
      return {
        'success': true,
        'mode': 'offline',
        'message': 'Sesión iniciada (modo offline)',
        'username': username
      };
    }
    
    return {
      'success': false,
      'mode': 'none',
      'message': 'No hay sesión guardada'
    };
  }

  /// Login offline usando datos guardados (método legacy)
  static Future<bool> loginOffline() async {
    final storedData = await LocalStorageService.getUserData();
    return storedData != null;
  }

  /// Recupera el token guardado
  static Future<String?> get token async {
    return await LocalStorageService.getToken();
  }

  /// Obtiene el nombre de usuario guardado
  static Future<String?> get savedUsername async {
    final storedData = await LocalStorageService.getUserData();
    return storedData?['username'];
  }

  /// Obtiene el tipo de usuario guardado
  static Future<String> get userType async {
    final storedData = await LocalStorageService.getUserData();
    return storedData?['user_type'] ?? 'vacunador';
  }

  /// Verifica si hay una sesión activa
  static Future<bool> isLoggedIn() async {
    final userData = await LocalStorageService.getUserData();
    return userData != null; // Solo verificar que haya credenciales guardadas
  }

  /// Elimina todos los datos (logout completo)
  static Future<void> logout() async {
    await LocalStorageService.logoutButKeepCredentials();
  }

  /// Elimina TODOS los datos incluyendo credenciales (logout completo)
  static Future<void> logoutCompletely() async {
    await LocalStorageService.clearAllData();
  }
}
