// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item.dart';

class ApiService {
  // URL base apuntando al endpoint de items en tu Django
  static const String _baseUrl = 'http://localhost:8000/api/items/';

  /// Recupera la lista de items desde el backend
  static Future<List<Item>> fetchItems() async {
    final url = Uri.parse(_baseUrl);
    print('🚀 GET → $url');
    final resp = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );
    print('📥 GET status: ${resp.statusCode}, body: ${resp.body}');
    if (resp.statusCode == 200) {
      final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
      return data
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Error al cargar items: ${resp.statusCode}');
    }
  }

  /// Crea un nuevo item en el backend
  static Future<Item> createItem(String nombre) async {
    final url = Uri.parse(_baseUrl);
    final body = json.encode({'nombre': nombre});
    print('🚀 POST → $url, body: $body');
    try {
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      print('📤 POST status: ${resp.statusCode}, body: ${resp.body}');
      if (resp.statusCode == 201) {
        return Item.fromJson(json.decode(resp.body) as Map<String, dynamic>);
      } else {
        throw Exception('Error al crear item: ${resp.statusCode}');
      }
    } catch (e) {
      print('❌ EXCEPCIÓN en createItem: $e');
      rethrow;
    }
  }
}
