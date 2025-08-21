// lib/services/sync_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/planilla_service.dart';
import '../services/responsable_service.dart';
import '../services/local_storage_service.dart';

/// Estructura de un pendiente de mascota
class PendingMascota {
  final int planId;
  final String nombre;
  final String timestamp;

  PendingMascota({required this.planId, required this.nombre, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'nombre': nombre,
    'timestamp': timestamp,
  };

  factory PendingMascota.fromJson(Map<String, dynamic> json) => PendingMascota(
    planId: json['planId'] as int,
    nombre: json['nombre'] as String,
    timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
  );
}

/// Estructura de un pendiente de responsable
class PendingResponsable {
  final int planillaId;
  final String nombre;
  final String telefono;
  final String finca;
  final String zona;
  final String nombreZona;
  final String loteVacuna;
  final List<Map<String, dynamic>> mascotas;
  final String timestamp;

  PendingResponsable({
    required this.planillaId,
    required this.nombre,
    required this.telefono,
    required this.finca,
    required this.zona,
    required this.nombreZona,
    required this.loteVacuna,
    required this.mascotas,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'planillaId': planillaId,
    'nombre': nombre,
    'telefono': telefono,
    'finca': finca,
    'zona': zona,
    'nombre_zona': nombreZona,
    'lote_vacuna': loteVacuna,
    'mascotas': mascotas,
    'timestamp': timestamp,
  };

  factory PendingResponsable.fromJson(Map<String, dynamic> json) => PendingResponsable(
    planillaId: json['planillaId'] as int,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String,
    finca: json['finca'] as String,
    zona: json['zona'] as String? ?? 'vereda',
    nombreZona: json['nombre_zona'] as String? ?? '',
    loteVacuna: json['lote_vacuna'] as String? ?? '',
    mascotas: (json['mascotas'] as List).cast<Map<String, dynamic>>(),
    timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
  );
}

class SyncService {
  static const _key = 'PENDING_MASCOTAS';
  // Usar la misma clave que LocalStorageService para evitar duplicados
  static const _keyResponsables = 'pending_responsables';
  static bool _isSyncing = false;
  static bool _listenerStarted = false;
  static StreamSubscription<ConnectivityResult>? _connectivitySub;

  /// Obtiene el número de items pendientes
  static Future<int> getPendingCount() async {
    final responsables = await LocalStorageService.getPendingResponsables();
    final prefs = await SharedPreferences.getInstance();
    final mascotasRaw = prefs.getString(_key);
    final mascotas = mascotasRaw == null ? [] : json.decode(mascotasRaw) as List;
    
    return responsables.length + mascotas.length;
  }

  /// Obtiene todos los items pendientes para mostrar en historial
  static Future<Map<String, dynamic>> getPendingItems() async {
    final responsables = await LocalStorageService.getPendingResponsables();
    final prefs = await SharedPreferences.getInstance();
    final mascotasRaw = prefs.getString(_key);
    final mascotas = mascotasRaw == null ? [] : json.decode(mascotasRaw) as List;
    
    return {
      'responsables': responsables,
      'mascotas': mascotas,
      'total': responsables.length + mascotas.length,
    };
  }

  /// Encola una mascota cuando no hay conexión
  static Future<void> queueMascota(int planId, String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final list = raw == null ? <dynamic>[] : json.decode(raw) as List<dynamic>;
    
    // Verificar si ya existe una mascota con el mismo nombre para la misma planilla
    final exists = list.any((item) => 
      item['planId'] == planId && item['nombre'] == nombre
    );
    
    if (!exists) {
      list.add({
        'planId': planId, 
        'nombre': nombre, 
        'timestamp': DateTime.now().toIso8601String()
      });
      await prefs.setString(_key, json.encode(list));
      print('✅ Mascota encolada para sincronización: $nombre');
    } else {
      print('⚠️ Mascota ya existe en la cola: $nombre');
    }
  }

  /// Encola un responsable cuando no hay conexión
  static Future<void> queueResponsable(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    String zona,
    String nombreZona,
    String loteVacuna,
    List<Map<String, dynamic>> mascotas,
  ) async {
    // Verificar si ya existe un responsable con el mismo nombre para la misma planilla
    final existing = await LocalStorageService.getPendingResponsables();
    final exists = existing.any((item) => 
      item['planillaId'] == planillaId && item['nombre'] == nombre
    );
    
    if (!exists) {
      await LocalStorageService.savePendingResponsable(
        planillaId, nombre, telefono, finca, zona, nombreZona, loteVacuna, mascotas,
      );
      print('✅ Responsable encolado para sincronización: $nombre');
    } else {
      print('⚠️ Responsable ya existe en la cola: $nombre');
    }
  }

  /// Intenta enviar todas las mascotas encoladas
  static Future<Map<String, dynamic>> syncMascotas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {'success': 0, 'failed': 0, 'errors': []};
    
    // Desduplicar mascotas por (planId, nombre)
    final decoded = (json.decode(raw) as List<dynamic>)
        .map((e) => PendingMascota.fromJson(e as Map<String, dynamic>))
        .toList();
    final Map<String, PendingMascota> unique = {};
    for (final pm in decoded) {
      final key = '${pm.planId}::${pm.nombre.trim().toLowerCase()}';
      unique.putIfAbsent(key, () => pm);
    }
    final pending = unique.values.toList();
    
    final List<PendingMascota> remaining = [];
    final List<String> errors = [];
    int successCount = 0;

    print('🔄 Sincronizando ${pending.length} mascotas...');

    for (final pm in pending) {
      try {
        print('📤 Sincronizando mascota: ${pm.nombre} para planilla ${pm.planId}');
        await PlanillaService.createMascota(pm.planId, pm.nombre);
        successCount++;
        print('✅ Mascota sincronizada exitosamente: ${pm.nombre}');
      } catch (e) {
        print('❌ Error sincronizando mascota ${pm.nombre}: $e');
        errors.add('Mascota ${pm.nombre}: $e');
        remaining.add(pm);
      }
    }

    // Actualizar la lista de pendientes
    if (remaining.isEmpty) {
      await prefs.remove(_key);
      print('🎉 Todas las mascotas fueron sincronizadas');
    } else {
      final remJson = remaining.map((e) => e.toJson()).toList();
      await prefs.setString(_key, json.encode(remJson));
      print('⚠️ Quedan ${remaining.length} mascotas pendientes');
    }

    return {
      'success': successCount,
      'failed': remaining.length,
      'errors': errors,
    };
  }

  /// Intenta enviar todos los responsables encolados
  static Future<Map<String, dynamic>> syncResponsables() async {
    final rawPending = await LocalStorageService.getPendingResponsables();
    // Desduplicar responsables por (planillaId, nombre)
    final Map<String, Map<String, dynamic>> unique = {};
    for (final r in rawPending) {
      final key = '${r['planillaId']}::${(r['nombre'] as String).trim().toLowerCase()}';
      unique.putIfAbsent(key, () => r);
    }
    final pending = unique.values.toList();
    if (pending.isEmpty) return {'success': 0, 'failed': 0, 'errors': []};

    final List<Map<String, dynamic>> remaining = [];
    final List<String> errors = [];
    int successCount = 0;

    print('🔄 Sincronizando ${pending.length} responsables...');

    for (int i = 0; i < pending.length; i++) {
      final pr = pending[i];
      try {
        print('📤 Sincronizando responsable: ${pr['nombre']} para planilla ${pr['planillaId']}');
        
        final resultado = await ResponsableService.createResponsable(
          pr['planillaId'] as int,
          pr['nombre'] as String,
          pr['telefono'] as String,
          pr['finca'] as String,
          pr['zona'] as String? ?? 'vereda',
          pr['nombre_zona'] as String? ?? '',
          pr['lote_vacuna'] as String? ?? '',
          (pr['mascotas'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
        
        // Si el responsable se creó exitosamente, no agregarlo a remaining
        if (resultado != null) {
          successCount++;
          print('✅ Responsable sincronizado exitosamente: ${pr['nombre']}');
        } else {
          print('❌ ResponsableService retornó null para: ${pr['nombre']}');
          errors.add('Responsable ${pr['nombre']}: Error del servidor');
          remaining.add(pr);
        }
      } catch (e) {
        print('❌ Error sincronizando responsable ${pr['nombre']}: $e');
        errors.add('Responsable ${pr['nombre']}: $e');
        remaining.add(pr);
      }
    }

    // Limpiar todos los pendientes y guardar solo los que fallaron
    await LocalStorageService.clearPendingResponsables();
    
    if (remaining.isNotEmpty) {
      // Volver a guardar solo los que fallaron
      for (final r in remaining) {
        await LocalStorageService.savePendingResponsable(
          r['planillaId'] as int,
          r['nombre'] as String,
          r['telefono'] as String,
          r['finca'] as String,
          r['zona'] as String? ?? 'vereda',
          r['nombre_zona'] as String? ?? '',
          r['lote_vacuna'] as String? ?? '',
          (r['mascotas'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
      }
      print('⚠️ Quedan ${remaining.length} responsables pendientes');
    } else {
      print('🎉 Todos los responsables fueron sincronizados');
    }

    return {
      'success': successCount,
      'failed': remaining.length,
      'errors': errors,
    };
  }

  /// Sincroniza todo (mascotas y responsables)
  static Future<Map<String, dynamic>> syncAll() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en curso. Se omite llamada adicional.');
      return {'success': 0, 'failed': 0, 'errors': <String>[], 'mascotas': {}, 'responsables': {}};
    }
    _isSyncing = true;
    try {
      print('🔄 Iniciando sincronización completa...');
      final mascotasResult = await syncMascotas();
      final responsablesResult = await syncResponsables();
      final totalSuccess = (mascotasResult['success'] as int) + (responsablesResult['success'] as int);
      final totalFailed = (mascotasResult['failed'] as int) + (responsablesResult['failed'] as int);
      final allErrors = [
        ...((mascotasResult['errors'] as List?)?.cast<String>() ?? const <String>[]),
        ...((responsablesResult['errors'] as List?)?.cast<String>() ?? const <String>[]),
      ];
      print('✅ Sincronización completa: $totalSuccess exitosos, $totalFailed fallidos');
      return {
        'success': totalSuccess,
        'failed': totalFailed,
        'errors': allErrors,
        'mascotas': mascotasResult,
        'responsables': responsablesResult,
      };
    } finally {
      _isSyncing = false;
    }
  }

  /// Escucha cambios de red y sincroniza automáticamente
  static void startNetworkListener() {
    if (_listenerStarted) return;
    _listenerStarted = true;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        print('🌐 Conexión restaurada, iniciando sincronización automática...');
        final result = await syncAll();
        if ((result['success'] as int?) != null && (result['success'] as int) > 0) {
          print('🎉 Sincronización automática exitosa: ${result['success']} items');
        }
      }
    });
  }

  static Future<void> stopNetworkListener() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _listenerStarted = false;
  }

  /// Método legacy para compatibilidad
  static Future<void> syncPending() async {
    await syncAll();
  }

  /// Método legacy para compatibilidad
  static Future<void> queuItem(String nombre) async {
    // Método de compatibilidad - no implementado
    print('queuItem called but not implemented');
  }
}
