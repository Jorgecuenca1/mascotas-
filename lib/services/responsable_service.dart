// lib/services/responsable_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/responsable.dart';
import '../models/mascota.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';

class ResponsableService {
  static const _base = 'https://vacunacion.corpofuturo.org/api/';

  // Obtener todos los responsables de una planilla
  static Future<List<Responsable>> fetchResponsables(int planillaId) async {
    final t = await AuthService.token;
    final resp = await http.get(
      Uri.parse('${_base}planillas/$planillaId/responsables/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $t',
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Error ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as List<dynamic>;
    return data.map((e) => Responsable.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Crear un nuevo responsable con mascotas
  static Future<Responsable?> createResponsable(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    String zona,
    String nombreZona,
    String loteVacuna,
    List<Map<String, dynamic>> mascotas,
  ) async {
    try {
      // Verificar conectividad primero
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('❌ Sin conexión - guardando responsable offline');
        await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
        throw Exception('Sin conexión a internet');
      }

      final t = await AuthService.token;
      if (t == null || t.isEmpty) {
        print('❌ Sin token de autenticación - guardando responsable offline');
        await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
        throw Exception('Sin token de autenticación');
      }

      print('🔄 Enviando responsable a Django: $nombre');
      print('📤 URL: ${_base}planillas/$planillaId/responsables/');
      print('📤 Token: ${t.substring(0, 10)}...');
      print('📤 Datos: ${json.encode({
          'nombre': nombre,
          'telefono': telefono,
          'finca': finca,
          'zona': zona,
          'nombre_zona': nombreZona,
          'lote_vacuna': loteVacuna,
          'mascotas': mascotas,
      })}');

      // Usar multipart para enviar archivos de imagen
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${_base}planillas/$planillaId/responsables/'),
      );
      
      request.headers['Authorization'] = 'Token $t';
      
      // Agregar campos del responsable
      request.fields['nombre'] = nombre;
      request.fields['telefono'] = telefono;
      request.fields['finca'] = finca;
      request.fields['zona'] = zona;
      request.fields['nombre_zona'] = nombreZona;
      request.fields['lote_vacuna'] = loteVacuna;
      
      // Enviar mascotas con fotos incluidas en JSON (Django ya maneja base64)
      request.fields['mascotas'] = json.encode(mascotas);
      
      print('📤 Enviando multipart request...');
      final streamedResponse = await request.send().timeout(Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamedResponse);
      
      print('📥 Respuesta Django: ${resp.statusCode}');
      print('📥 Body: ${resp.body}');
      
      if (resp.statusCode == 201) {
        print('✅ Responsable creado exitosamente en Django');
        try {
          final responseData = json.decode(resp.body);
          return Responsable.fromJson(responseData);
        } catch (e) {
          print('⚠️ Error parseando respuesta Django: $e');
          // Aunque Django guardó correctamente, el parsing falló
          // Crear un responsable temporal para indicar éxito
          return Responsable(
            id: DateTime.now().millisecondsSinceEpoch,
            nombre: nombre,
            telefono: telefono,
            finca: finca,
            zona: zona,
            nombreZona: nombreZona,
            loteVacuna: loteVacuna,
            creado: DateTime.now(),
            mascotas: mascotas.map((m) => Mascota.fromJson(m)).toList(),
          );
        }
      } else {
        print('❌ Error del servidor Django: ${resp.statusCode}');
        print('❌ Mensaje: ${resp.body}');
        await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
        throw Exception('Error del servidor: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      // Si es XMLHttpRequest error o problema de red, guardar offline sin mostrar error
      if (e.toString().contains('XMLHttpRequest error') || 
          e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException')) {
        
        print('🌐 Sin conexión a Django. Guardando offline: $nombre');
        await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
        
        // Retornar null para indicar que se guardó offline exitosamente
        return null;
      } else {
        // Error real (parsing, servidor, etc.)
        print('❌ Error real creando responsable: $e');
        
        // Solo guardar offline si no es un error de parsing exitoso
        if (!e.toString().contains('Error parseando respuesta Django')) {
          await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
        }
        
        rethrow;
      }
    }
  }

  // Método auxiliar para guardar offline
  static Future<void> _saveOffline(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    String zona,
    String nombreZona,
    String loteVacuna,
    List<Map<String, dynamic>> mascotas,
  ) async {
    print('💾 Guardando responsable offline: $nombre');
        await LocalStorageService.savePendingResponsable(
          planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas,
        );
  }

  // Crear responsable offline (para uso directo)
  static Future<void> createResponsableOffline(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    String zona,
    String nombreZona,
    String loteVacuna,
    List<Map<String, dynamic>> mascotas,
  ) async {
    await _saveOffline(planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas);
  }

  // Verificar el estado de la conexión y mostrar información útil
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    final connectivity = await Connectivity().checkConnectivity();
    final token = await AuthService.token;
    final isOnline = connectivity != ConnectivityResult.none;
    final hasToken = token != null && token.isNotEmpty;
    
    String status = 'unknown';
    String message = '';
    
    if (!isOnline) {
      status = 'offline';
      message = 'Sin conexión a internet';
    } else if (!hasToken) {
      status = 'no_auth';
      message = 'Sin token de autenticación';
    } else {
      status = 'ready';
      message = 'Listo para sincronizar';
    }
    
    return {
      'status': status,
      'message': message,
      'isOnline': isOnline,
      'hasToken': hasToken,
      'token': hasToken ? '${token!.substring(0, 10)}...' : null,
    };
  }

  // Probar conexión con Django
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final status = await getConnectionStatus();
      if (status['status'] != 'ready') {
        return {
          'success': false,
          'message': status['message'],
          'details': status,
        };
      }

      final token = await AuthService.token;
      print('🧪 Probando conexión con Django...');
      
      final resp = await http.get(
        Uri.parse('${_base}planillas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ).timeout(Duration(seconds: 10));

      print('🧪 Respuesta de prueba: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        return {
          'success': true,
          'message': 'Conexión exitosa con Django',
          'details': {
            'status_code': resp.statusCode,
            'server': 'Django API',
          },
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor Django: ${resp.statusCode}',
          'details': {
            'status_code': resp.statusCode,
            'body': resp.body,
          },
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'details': {'error': e.toString()},
      };
    }
  }

  // Agregar mascota a un responsable existente
  static Future<Mascota> addMascotaToResponsable(
    int responsableId,
    String nombre,
    String tipo,
    String raza,
    String color,
    bool antecedenteVacunal,
  ) async {
    final t = await AuthService.token;
    final resp = await http.post(
      Uri.parse('${_base}responsables/$responsableId/mascotas/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $t',
      },
      body: json.encode({
        'nombre': nombre,
        'tipo': tipo,
        'raza': raza,
        'color': color,
        'antecedente_vacunal': antecedenteVacunal,
      }),
    );
    if (resp.statusCode != 201) {
      throw Exception('Error ${resp.statusCode}');
    }
    return Mascota.fromJson(json.decode(resp.body));
  }
} 