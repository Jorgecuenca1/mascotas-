// lib/services/sync_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/planilla_service.dart';
import '../services/responsable_service.dart';
import '../services/local_storage_service.dart';

/// Estructura de un pendiente de mascota
class PendingMascota {
  final int planId;
  final String nombre;

  PendingMascota({required this.planId, required this.nombre});

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'nombre': nombre,
  };

  factory PendingMascota.fromJson(Map<String, dynamic> json) => PendingMascota(
    planId: json['planId'] as int,
    nombre: json['nombre'] as String,
  );
}

/// Estructura de un pendiente de responsable
class PendingResponsable {
  final int planillaId;
  final String nombre;
  final String telefono;
  final String finca;
  final List<Map<String, dynamic>> mascotas;

  PendingResponsable({
    required this.planillaId,
    required this.nombre,
    required this.telefono,
    required this.finca,
    required this.mascotas,
  });

  Map<String, dynamic> toJson() => {
    'planillaId': planillaId,
    'nombre': nombre,
    'telefono': telefono,
    'finca': finca,
    'mascotas': mascotas,
  };

  factory PendingResponsable.fromJson(Map<String, dynamic> json) => PendingResponsable(
    planillaId: json['planillaId'] as int,
    nombre: json['nombre'] as String,
    telefono: json['telefono'] as String,
    finca: json['finca'] as String,
    mascotas: (json['mascotas'] as List).cast<Map<String, dynamic>>(),
  );
}

class SyncService {
  static const _key = 'PENDING_MASCOTAS';
  // Usar la misma clave que LocalStorageService para evitar duplicados
  static const _keyResponsables = 'pending_responsables';

  /// Obtiene el número de items pendientes
  static Future<int> getPendingCount() async {
    final responsables = await LocalStorageService.getPendingResponsables();
    final prefs = await SharedPreferences.getInstance();
    final mascotasRaw = prefs.getString(_key);
    final mascotas = mascotasRaw == null ? [] : json.decode(mascotasRaw) as List;
    
    return responsables.length + mascotas.length;
  }

  /// Encola una mascota cuando no hay conexión
  static Future<void> queueMascota(int planId, String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final list = raw == null ? <dynamic>[] : json.decode(raw) as List<dynamic>;
    list.add({'planId': planId, 'nombre': nombre, 'timestamp': DateTime.now().toIso8601String()});
    await prefs.setString(_key, json.encode(list));
    print('Mascota encolada para sincronización: $nombre');
  }

  /// Encola un responsable cuando no hay conexión
  static Future<void> queueResponsable(
    int planillaId,
    String nombre,
    String telefono,
    String finca,
    List<Map<String, dynamic>> mascotas,
  ) async {
    // Usar LocalStorageService para evitar duplicados
    await LocalStorageService.savePendingResponsable(
      planillaId, nombre, telefono, finca, mascotas,
    );
    print('Responsable encolado para sincronización: $nombre');
  }

  /// Intenta enviar todas las mascotas encoladas
  static Future<Map<String, dynamic>> syncMascotas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {'success': 0, 'failed': 0, 'errors': []};
    
    final pending = (json.decode(raw) as List<dynamic>)
        .map((e) => PendingMascota.fromJson(e as Map<String, dynamic>))
        .toList();
    
    final List<PendingMascota> remaining = [];
    final List<String> errors = [];
    int successCount = 0;

    for (final pm in pending) {
      try {
        print('Sincronizando mascota: ${pm.nombre} para planilla ${pm.planId}');
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
      print('Todas las mascotas fueron sincronizadas');
    } else {
      final remJson = remaining.map((e) => e.toJson()).toList();
      await prefs.setString(_key, json.encode(remJson));
      print('Quedan ${remaining.length} mascotas pendientes');
    }

    return {
      'success': successCount,
      'failed': remaining.length,
      'errors': errors,
    };
  }

  /// Intenta enviar todos los responsables encolados
  static Future<Map<String, dynamic>> syncResponsables() async {
    final pending = await LocalStorageService.getPendingResponsables();
    if (pending.isEmpty) return {'success': 0, 'failed': 0, 'errors': []};

    final List<Map<String, dynamic>> remaining = [];
    final List<String> errors = [];
    int successCount = 0;

    for (int i = 0; i < pending.length; i++) {
      final pr = pending[i];
      try {
        print('Sincronizando responsable: ${pr['nombre']} para planilla ${pr['planillaId']}');
        
        final resultado = await ResponsableService.createResponsable(
          pr['planillaId'] as int,
          pr['nombre'] as String,
          pr['telefono'] as String,
          pr['finca'] as String,
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
          (r['mascotas'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
      }
      print('Quedan ${remaining.length} responsables pendientes');
    } else {
      print('Todos los responsables fueron sincronizados');
    }

    return {
      'success': successCount,
      'failed': remaining.length,
      'errors': errors,
    };
  }

  /// Sincroniza todo (mascotas y responsables)
  static Future<Map<String, dynamic>> syncAll() async {
    print('🔄 Iniciando sincronización completa...');
    
    final mascotasResult = await syncMascotas();
    final responsablesResult = await syncResponsables();
    
    final totalSuccess = mascotasResult['success'] + responsablesResult['success'];
    final totalFailed = mascotasResult['failed'] + responsablesResult['failed'];
    final allErrors = [
      ...mascotasResult['errors'] as List<String>,
      ...responsablesResult['errors'] as List<String>,
    ];
    
    print('✅ Sincronización completa: $totalSuccess exitosos, $totalFailed fallidos');
    
    return {
      'success': totalSuccess,
      'failed': totalFailed,
      'errors': allErrors,
      'mascotas': mascotasResult,
      'responsables': responsablesResult,
    };
  }

  /// Escucha cambios de red y sincroniza automáticamente
  static void startNetworkListener() {
    Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        print('🌐 Conexión restaurada, iniciando sincronización automática...');
        final result = await syncAll();
        if (result['success'] > 0) {
          print('🎉 Sincronización automática exitosa: ${result['success']} items');
        }
      }
    });
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
