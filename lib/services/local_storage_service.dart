// lib/services/local_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/responsable.dart';
import '../models/mascota.dart';

class LocalStorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _pendingResponsablesKey = 'pending_responsables';
  static const String _planillasKey = 'planillas_data';

  // Guardar token de autenticación
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Obtener token guardado
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Guardar datos del usuario
  static Future<void> saveUserData(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode({
      'username': username,
      'password': password,
    }));
  }

  // Obtener datos del usuario
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userKey);
    if (data != null) {
      return json.decode(data) as Map<String, dynamic>;
    }
    return null;
  }

  // Guardar responsable pendiente
  static Future<void> savePendingResponsable(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    String zona,
    String nombreZona,
    String loteVacuna,
    List<Map<String, dynamic>> mascotas,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await getPendingResponsables();
    
    pending.add({
      'planillaId': planillaId,
      'nombre': nombre,
      'telefono': telefono,
      'finca': finca,
      'zona': zona,
      'nombre_zona': nombreZona,
      'lote_vacuna': loteVacuna,
      'mascotas': mascotas,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await prefs.setString(_pendingResponsablesKey, json.encode(pending));
  }

  // Obtener responsables pendientes
  static Future<List<Map<String, dynamic>>> getPendingResponsables() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_pendingResponsablesKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(json.decode(data));
    }
    return [];
  }

  // Eliminar responsable pendiente
  static Future<void> removePendingResponsable(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await getPendingResponsables();
    
    // Validar que el índice esté en rango
    if (index >= 0 && index < pending.length) {
    pending.removeAt(index);
    await prefs.setString(_pendingResponsablesKey, json.encode(pending));
    } else {
      print('⚠️ Índice fuera de rango: $index, lista tiene ${pending.length} elementos');
    }
  }

  // Limpiar todos los pendientes
  static Future<void> clearPendingResponsables() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingResponsablesKey);
  }

  // Guardar planillas localmente
  static Future<void> savePlanillas(List<Map<String, dynamic>> planillas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planillasKey, json.encode(planillas));
  }

  // Obtener planillas guardadas
  static Future<List<Map<String, dynamic>>> getPlanillas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_planillasKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(json.decode(data));
    }
    return [];
  }

  // Verificar si hay datos guardados
  static Future<bool> hasStoredData() async {
    final token = await getToken();
    return token != null;
  }

  // Limpiar todos los datos
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_pendingResponsablesKey);
    await prefs.remove(_planillasKey);
  }

  // Logout que conserva credenciales para login offline
  static Future<void> logoutButKeepCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // Solo eliminar token, conservar user_data
    // Las credenciales (_userKey) se mantienen para login offline
    // Los datos de planillas también se mantienen para trabajo offline
  }
} 