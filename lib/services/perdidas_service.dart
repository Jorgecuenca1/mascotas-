import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class PerdidasService {
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  static Future<void> registrarPerdida(Map<String, dynamic> perdidaData) async {
    final url = Uri.parse('${ApiConfig.apiBase}perdidas/');
    final headers = await _getHeaders();
    
    final body = json.encode({
      'cantidad': perdidaData['cantidad'],
      'lote_vacuna': perdidaData['lote_vacuna'],
      'motivo': perdidaData['motivo'],
      'fecha_perdida': perdidaData['fecha_perdida'],
      'latitud': perdidaData['latitud'],
      'longitud': perdidaData['longitud'],
      'foto_base64': perdidaData['foto_base64'],
      'uuid_local': perdidaData['uuid_local'],
    });

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    if (response.statusCode != 201) {
      throw Exception('Error al registrar pérdida: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerPerdidas() async {
    final url = Uri.parse('${ApiConfig.apiBase}perdidas/');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener pérdidas: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final url = Uri.parse('${ApiConfig.apiBase}perdidas/estadisticas/');
    final headers = await _getHeaders();

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener estadísticas: ${response.statusCode}');
    }
  }

  static Future<void> sincronizarPerdidasLocales(List<Map<String, dynamic>> perdidasLocales) async {
    for (var perdida in perdidasLocales) {
      if (perdida['sincronizado'] == false || perdida['sincronizado'] == 0) {
        try {
          await registrarPerdida(perdida);
          perdida['sincronizado'] = true;
        } catch (e) {
          print('Error sincronizando pérdida ${perdida['uuid_local']}: $e');
        }
      }
    }
  }
}