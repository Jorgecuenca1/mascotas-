import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static const String _perdidasKey = 'perdidas_locales';
  static const String _responsablesKey = 'responsables_locales';
  static const String _mascotasKey = 'mascotas_locales';

  Future<int> guardarPerdidaLocal(Map<String, dynamic> perdida) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Obtener pérdidas existentes
    final perdidasJson = prefs.getString(_perdidasKey);
    final List<Map<String, dynamic>> perdidas = perdidasJson != null 
        ? (json.decode(perdidasJson) as List).cast<Map<String, dynamic>>()
        : [];
    
    // Agregar fecha de registro si no existe
    perdida['fecha_registro'] = perdida['fecha_registro'] ?? DateTime.now().toIso8601String();
    perdida['id'] = DateTime.now().millisecondsSinceEpoch;
    
    // Agregar nueva pérdida
    perdidas.add(perdida);
    
    // Guardar de vuelta
    await prefs.setString(_perdidasKey, json.encode(perdidas));
    
    return perdida['id'] as int;
  }

  Future<List<Map<String, dynamic>>> obtenerPerdidasNoSincronizadas() async {
    final prefs = await SharedPreferences.getInstance();
    final perdidasJson = prefs.getString(_perdidasKey);
    
    if (perdidasJson == null) return [];
    
    final List<dynamic> perdidas = json.decode(perdidasJson);
    return perdidas
        .cast<Map<String, dynamic>>()
        .where((p) => p['sincronizado'] == false || p['sincronizado'] == 0)
        .toList();
  }

  Future<int> marcarPerdidaComoSincronizada(String uuidLocal) async {
    final prefs = await SharedPreferences.getInstance();
    final perdidasJson = prefs.getString(_perdidasKey);
    
    if (perdidasJson == null) return 0;
    
    final List<dynamic> perdidas = json.decode(perdidasJson);
    
    for (var perdida in perdidas) {
      if (perdida['uuid_local'] == uuidLocal) {
        perdida['sincronizado'] = true;
        break;
      }
    }
    
    await prefs.setString(_perdidasKey, json.encode(perdidas));
    return 1;
  }

  Future<List<Map<String, dynamic>>> obtenerTodasLasPerdidas() async {
    final prefs = await SharedPreferences.getInstance();
    final perdidasJson = prefs.getString(_perdidasKey);
    
    if (perdidasJson == null) return [];
    
    final List<dynamic> perdidas = json.decode(perdidasJson);
    return perdidas.cast<Map<String, dynamic>>();
  }

  Future<int> eliminarPerdidaLocal(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final perdidasJson = prefs.getString(_perdidasKey);
    
    if (perdidasJson == null) return 0;
    
    final List<dynamic> perdidas = json.decode(perdidasJson);
    perdidas.removeWhere((p) => p['id'] == id);
    
    await prefs.setString(_perdidasKey, json.encode(perdidas));
    return 1;
  }

  Future<int> guardarResponsableLocal(Map<String, dynamic> responsable) async {
    final prefs = await SharedPreferences.getInstance();
    
    final responsablesJson = prefs.getString(_responsablesKey);
    final List<Map<String, dynamic>> responsables = responsablesJson != null 
        ? (json.decode(responsablesJson) as List).cast<Map<String, dynamic>>()
        : [];
    
    responsable['fecha_registro'] = responsable['fecha_registro'] ?? DateTime.now().toIso8601String();
    responsable['id'] = DateTime.now().millisecondsSinceEpoch;
    
    responsables.add(responsable);
    
    await prefs.setString(_responsablesKey, json.encode(responsables));
    
    return responsable['id'] as int;
  }

  Future<int> guardarMascotaLocal(Map<String, dynamic> mascota) async {
    final prefs = await SharedPreferences.getInstance();
    
    final mascotasJson = prefs.getString(_mascotasKey);
    final List<Map<String, dynamic>> mascotas = mascotasJson != null 
        ? (json.decode(mascotasJson) as List).cast<Map<String, dynamic>>()
        : [];
    
    mascota['fecha_registro'] = mascota['fecha_registro'] ?? DateTime.now().toIso8601String();
    mascota['id'] = DateTime.now().millisecondsSinceEpoch;
    
    mascotas.add(mascota);
    
    await prefs.setString(_mascotasKey, json.encode(mascotas));
    
    return mascota['id'] as int;
  }

  Future<List<Map<String, dynamic>>> obtenerResponsablesNoSincronizados() async {
    final prefs = await SharedPreferences.getInstance();
    final responsablesJson = prefs.getString(_responsablesKey);
    
    if (responsablesJson == null) return [];
    
    final List<dynamic> responsables = json.decode(responsablesJson);
    return responsables
        .cast<Map<String, dynamic>>()
        .where((r) => r['sincronizado'] == false || r['sincronizado'] == 0)
        .toList();
  }

  Future<List<Map<String, dynamic>>> obtenerMascotasNoSincronizadas() async {
    final prefs = await SharedPreferences.getInstance();
    final mascotasJson = prefs.getString(_mascotasKey);
    
    if (mascotasJson == null) return [];
    
    final List<dynamic> mascotas = json.decode(mascotasJson);
    return mascotas
        .cast<Map<String, dynamic>>()
        .where((m) => m['sincronizado'] == false || m['sincronizado'] == 0)
        .toList();
  }
}