import 'dart:async';
import 'database_service_web.dart';
import 'perdidas_service.dart';
import 'connectivity_service.dart';

class PerdidasSyncService {
  static final PerdidasSyncService _instance = PerdidasSyncService._internal();
  factory PerdidasSyncService() => _instance;
  PerdidasSyncService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  Timer? _syncTimer;
  bool _isSyncing = false;

  void startAutoSync() {
    // Detener timer anterior si existe
    stopAutoSync();
    
    // Sincronizar inmediatamente
    syncPendingData();
    
    // Configurar sincronización cada 30 segundos
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncPendingData();
    });

    // Escuchar cambios de conectividad
    _connectivityService.initConnectivityListener((bool isOnline) {
      if (isOnline) {
        print('📡 Conexión detectada, sincronizando pérdidas...');
        syncPendingData();
      }
    });
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso, saltando...');
      return;
    }

    _isSyncing = true;

    try {
      bool hasConnection = await _connectivityService.hasConnection();
      
      if (!hasConnection) {
        print('📵 Sin conexión, no se puede sincronizar');
        return;
      }

      // Sincronizar pérdidas pendientes
      await _syncPerdidas();
      
      // También sincronizar responsables y mascotas si es necesario
      await _syncResponsables();
      await _syncMascotas();
      
    } catch (e) {
      print('❌ Error durante sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncPerdidas() async {
    try {
      List<Map<String, dynamic>> perdidasPendientes = 
          await _databaseService.obtenerPerdidasNoSincronizadas();
      
      if (perdidasPendientes.isEmpty) {
        print('✅ No hay pérdidas pendientes de sincronizar');
        return;
      }

      print('📤 Sincronizando ${perdidasPendientes.length} pérdidas...');
      
      for (var perdida in perdidasPendientes) {
        try {
          await PerdidasService.registrarPerdida(perdida);
          
          // Marcar como sincronizada
          if (perdida['uuid_local'] != null) {
            await _databaseService.marcarPerdidaComoSincronizada(
              perdida['uuid_local'].toString()
            );
            print('✅ Pérdida ${perdida['uuid_local']} sincronizada');
          }
        } catch (e) {
          print('❌ Error sincronizando pérdida ${perdida['uuid_local']}: $e');
        }
      }
    } catch (e) {
      print('❌ Error obteniendo pérdidas pendientes: $e');
    }
  }

  Future<void> _syncResponsables() async {
    try {
      List<Map<String, dynamic>> responsablesPendientes = 
          await _databaseService.obtenerResponsablesNoSincronizados();
      
      if (responsablesPendientes.isEmpty) {
        return;
      }

      print('📤 Sincronizando ${responsablesPendientes.length} responsables...');
      
      // Aquí implementarías la sincronización de responsables
      // Similar a como se hace con las pérdidas
      
    } catch (e) {
      print('❌ Error sincronizando responsables: $e');
    }
  }

  Future<void> _syncMascotas() async {
    try {
      List<Map<String, dynamic>> mascotasPendientes = 
          await _databaseService.obtenerMascotasNoSincronizadas();
      
      if (mascotasPendientes.isEmpty) {
        return;
      }

      print('📤 Sincronizando ${mascotasPendientes.length} mascotas...');
      
      // Aquí implementarías la sincronización de mascotas
      // Similar a como se hace con las pérdidas
      
    } catch (e) {
      print('❌ Error sincronizando mascotas: $e');
    }
  }

  Future<Map<String, int>> getPendingCounts() async {
    try {
      final perdidas = await _databaseService.obtenerPerdidasNoSincronizadas();
      final responsables = await _databaseService.obtenerResponsablesNoSincronizados();
      final mascotas = await _databaseService.obtenerMascotasNoSincronizadas();
      
      return {
        'perdidas': perdidas.length,
        'responsables': responsables.length,
        'mascotas': mascotas.length,
        'total': perdidas.length + responsables.length + mascotas.length,
      };
    } catch (e) {
      print('Error obteniendo conteos pendientes: $e');
      return {
        'perdidas': 0,
        'responsables': 0,
        'mascotas': 0,
        'total': 0,
      };
    }
  }
}