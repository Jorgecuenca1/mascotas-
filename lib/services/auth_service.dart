// lib/services/auth_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage_service.dart';

class AuthService {
  static const _base = 'https://vacunacion.corpofuturo.org/';

  /// Intenta hacer login online, si falla permite offline
  static Future<Map<String, dynamic>> login(String user, String pass) async {
    try {
      // Verificar conectividad
      final connectivity = await Connectivity().checkConnectivity();
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar login online
        try {
        final resp = await http.post(
          Uri.parse('${_base}api-token-auth/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': user, 'password': pass}),
          ).timeout(Duration(seconds: 10));
        
        if (resp.statusCode == 200) {
          final token = json.decode(resp.body)['token'] as String;
          await LocalStorageService.saveToken(token);
          await LocalStorageService.saveUserData(user, pass);
            return {
              'success': true,
              'mode': 'online',
              'message': 'Login exitoso (online)'
            };
        } else {
            // Si falla online, intentar offline
            return await _tryOfflineLogin(user, pass, 'Credenciales incorrectas en servidor');
          }
        } catch (e) {
          // Si hay error de red, intentar offline
          return await _tryOfflineLogin(user, pass, 'Error de conexión con servidor');
        }
      } else {
        // Sin conexión, verificar offline
        return await _tryOfflineLogin(user, pass, 'Sin conexión a internet');
      }
    } catch (e) {
      return {
        'success': false,
        'mode': 'error',
        'message': 'Error inesperado: $e'
      };
    }
  }

  /// Intenta login offline con credenciales guardadas
  static Future<Map<String, dynamic>> _tryOfflineLogin(String user, String pass, String reason) async {
        final storedData = await LocalStorageService.getUserData();
        if (storedData != null && 
            storedData['username'] == user && 
            storedData['password'] == pass) {
      return {
        'success': true,
        'mode': 'offline',
        'message': 'Login exitoso (modo offline)'
      };
        } else {
      return {
        'success': false,
        'mode': 'offline',
        'message': '$reason. No hay credenciales válidas guardadas.'
      };
    }
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
