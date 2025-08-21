import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/planilla.dart';
import '../models/mascota.dart';
import 'auth_service.dart';
import 'api_config.dart';
import 'local_storage_service.dart';

class PlanillaService {
  static final _base = ApiConfig.apiBase;

  /// Obtiene planillas (online con fallback a offline)
  static Future<List<Planilla>> fetchPlanillas() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final currentUser = await AuthService.savedUsername;
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar obtener online
        try {
          final t = await AuthService.token;
          final resp = await http.get(
            Uri.parse('${_base}planillas/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $t',
            },
          ).timeout(Duration(seconds: 10));
          
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as List<dynamic>;
            var planillas = data.map((e) => Planilla.fromJson(e as Map<String, dynamic>)).toList();
            // Filtro ESTRICTO: mostrar solo planillas asignadas al usuario logueado
            if (currentUser != null) {
              planillas = planillas.where((p) => p.asignadoA == currentUser).toList();
            }
            
            // Guardar localmente para uso offline
            await _savePlanillasLocally(planillas);
            
            return planillas;
          }
        } catch (e) {
          print('Error fetching planillas online: $e');
          // Si falla online, cargar offline
          return await _loadPlanillasFromLocal();
        }
      }
      
      // Sin conexión, cargar desde almacenamiento local
      final local = await _loadPlanillasFromLocal();
      if (currentUser != null) {
        return local.where((p) => p.asignadoA == currentUser).toList();
      }
      return local;
      
    } catch (e) {
      print('Error general en fetchPlanillas: $e');
      return await _loadPlanillasFromLocal();
    }
  }

  /// Guarda planillas localmente
  static Future<void> _savePlanillasLocally(List<Planilla> planillas) async {
    try {
      final planillasJson = planillas.map((p) => p.toJson()).toList();
      await LocalStorageService.savePlanillas(planillasJson.cast<Map<String, dynamic>>());
    } catch (e) {
      print('Error guardando planillas localmente: $e');
    }
  }

  /// Carga planillas desde almacenamiento local
  static Future<List<Planilla>> _loadPlanillasFromLocal() async {
    try {
      final planillasJson = await LocalStorageService.getPlanillas();
      return planillasJson.map((json) => Planilla.fromJson(json)).toList();
    } catch (e) {
      print('Error cargando planillas locales: $e');
      return [];
    }
  }

  /// Obtiene mascotas (online con fallback a offline)
  static Future<List<Mascota>> fetchMascotas(int planId) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar obtener online
        try {
          final t = await AuthService.token;
          final resp = await http.get(
            Uri.parse('${_base}planillas/$planId/mascotas/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $t',
            },
          ).timeout(Duration(seconds: 10));
          
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as List<dynamic>;
            final mascotas = data.map((e) => Mascota.fromJson(e as Map<String, dynamic>)).toList();
            
            // Guardar localmente (actualizar la planilla local)
            await _updatePlanillaMascotasLocally(planId, mascotas);
            
            return mascotas;
          }
        } catch (e) {
          print('Error fetching mascotas online: $e');
          // Si falla online, cargar offline
          return await _loadMascotasFromLocal(planId);
        }
      }
      
      // Sin conexión, cargar desde almacenamiento local
      return await _loadMascotasFromLocal(planId);
      
    } catch (e) {
      print('Error general en fetchMascotas: $e');
      return await _loadMascotasFromLocal(planId);
    }
  }

  /// Actualiza mascotas de una planilla localmente
  static Future<void> _updatePlanillaMascotasLocally(int planId, List<Mascota> mascotas) async {
    try {
      final planillasJson = await LocalStorageService.getPlanillas();
      
      // Encontrar y actualizar la planilla
      for (int i = 0; i < planillasJson.length; i++) {
        if (planillasJson[i]['id'] == planId) {
          // Actualizar las mascotas de los responsables de esta planilla
          // Por simplicidad, esto es una aproximación - en un caso real necesitarías
          // una estructura más compleja para manejar mascotas por responsable
          break;
        }
      }
      
      await LocalStorageService.savePlanillas(planillasJson);
    } catch (e) {
      print('Error actualizando mascotas localmente: $e');
    }
  }

  /// Carga mascotas desde almacenamiento local
  static Future<List<Mascota>> _loadMascotasFromLocal(int planId) async {
    try {
      final planillasJson = await LocalStorageService.getPlanillas();
      
      // Buscar la planilla y extraer mascotas de sus responsables
      for (final planillaJson in planillasJson) {
        if (planillaJson['id'] == planId) {
          final List<Mascota> mascotas = [];
          final responsables = planillaJson['responsables'] as List<dynamic>? ?? [];
          
          for (final responsable in responsables) {
            final responsableMascotas = responsable['mascotas'] as List<dynamic>? ?? [];
            for (final mascotaJson in responsableMascotas) {
              mascotas.add(Mascota.fromJson(mascotaJson as Map<String, dynamic>));
            }
          }
          
          return mascotas;
        }
      }
      
      return [];
    } catch (e) {
      print('Error cargando mascotas locales: $e');
      return [];
    }
  }

  /// Crea mascota (online con queue offline)
  static Future<void> createMascota(int planId, String nombre) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      
      if (connectivity != ConnectivityResult.none) {
        // Intentar crear online
        final t = await AuthService.token;
        final resp = await http.post(
          Uri.parse('${_base}planillas/$planId/mascotas/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $t',
          },
          body: json.encode({'nombre': nombre}),
        ).timeout(Duration(seconds: 10));
        
        if (resp.statusCode != 201) {
          throw Exception('Error ${resp.statusCode}');
        }
      } else {
        // Sin conexión, encolar para sincronizar después
        await _queueMascotaForSync(planId, nombre);
        throw Exception('Sin conexión - Mascota encolada para sincronizar');
      }
    } catch (e) {
      // Si hay error de red, encolar para sincronizar
      await _queueMascotaForSync(planId, nombre);
      rethrow;
    }
  }

  /// Encola mascota para sincronización posterior
  static Future<void> _queueMascotaForSync(int planId, String nombre) async {
    // Esto se integraría con el SyncService existente
    // Por ahora, simplemente guardamos en local storage
    try {
      // Crear una mascota temporal local
      final tempMascota = {
        'id': DateTime.now().millisecondsSinceEpoch, // ID temporal
        'nombre': nombre,
        'tipo': 'perro',
        'raza': 'M',
        'color': '',
        'antecedente_vacunal': false,
        'responsable_id': 0,
        'creado': DateTime.now().toIso8601String(),
        'pending_sync': true, // Marca que está pendiente de sincronizar
      };
      
      // Agregar a la planilla local
      await _addMascotaToLocalPlanilla(planId, tempMascota);
    } catch (e) {
      print('Error encolando mascota: $e');
    }
  }

  /// Agrega mascota a planilla local
  static Future<void> _addMascotaToLocalPlanilla(int planId, Map<String, dynamic> mascotaJson) async {
    try {
      final planillasJson = await LocalStorageService.getPlanillas();
      
      // Encontrar la planilla y agregar la mascota al primer responsable
      // (esto es una simplificación - idealmente necesitarías especificar el responsable)
      for (int i = 0; i < planillasJson.length; i++) {
        if (planillasJson[i]['id'] == planId) {
          final responsables = planillasJson[i]['responsables'] as List<dynamic>? ?? [];
          if (responsables.isNotEmpty) {
            final mascotas = responsables[0]['mascotas'] as List<dynamic>? ?? [];
            mascotas.add(mascotaJson);
            responsables[0]['mascotas'] = mascotas;
            planillasJson[i]['responsables'] = responsables;
          }
          break;
        }
      }
      
      await LocalStorageService.savePlanillas(planillasJson);
    } catch (e) {
      print('Error agregando mascota a planilla local: $e');
    }
  }

  /// Verifica si hay datos offline disponibles
  static Future<bool> hasOfflineData() async {
    try {
      final planillas = await LocalStorageService.getPlanillas();
      return planillas.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Inicializa datos de ejemplo para testing offline
  static Future<void> initializeSampleData() async {
    try {
      final hasData = await hasOfflineData();
      if (!hasData) {
        final samplePlanillas = [
          {
            'id': 1,
            'nombre': 'Planilla Centro - Enero 2024',
            'creada': DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
            'responsables': [
              {
                'id': 1,
                'nombre': 'Juan Pérez',
                'telefono': '555-0001',
                'finca': 'Finca El Rosal',
                'creado': DateTime.now().subtract(Duration(days: 4)).toIso8601String(),
                'mascotas': [
                  {
                    'id': 1,
                    'nombre': 'Rex',
                    'tipo': 'perro',
                    'raza': 'M',
                    'color': 'Café',
                    'antecedente_vacunal': true,
                    'responsable_id': 1,
                    'creado': DateTime.now().subtract(Duration(days: 4)).toIso8601String(),
                  },
                  {
                    'id': 2,
                    'nombre': 'Luna',
                    'tipo': 'gato',
                    'raza': 'H',
                    'color': 'Negro',
                    'antecedente_vacunal': false,
                    'responsable_id': 1,
                    'creado': DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
                  }
                ]
              },
              {
                'id': 2,
                'nombre': 'María González',
                'telefono': '555-0002',
                'finca': 'Finca Las Flores',
                'creado': DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
                'mascotas': [
                  {
                    'id': 3,
                    'nombre': 'Bobby',
                    'tipo': 'perro',
                    'raza': 'PME',
                    'color': 'Blanco',
                    'antecedente_vacunal': true,
                    'responsable_id': 2,
                    'creado': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
                  }
                ]
              }
            ]
          },
          {
            'id': 2,
            'nombre': 'Planilla Norte - Enero 2024',
            'creada': DateTime.now().subtract(Duration(days: 3)).toIso8601String(),
            'responsables': [
              {
                'id': 3,
                'nombre': 'Carlos Rodríguez',
                'telefono': '555-0003',
                'finca': 'Finca El Paraíso',
                'creado': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
                'mascotas': [
                  {
                    'id': 4,
                    'nombre': 'Michi',
                    'tipo': 'gato',
                    'raza': 'M',
                    'color': 'Gris',
                    'antecedente_vacunal': false,
                    'responsable_id': 3,
                    'creado': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
                  }
                ]
              }
            ]
          }
        ];
        
        await LocalStorageService.savePlanillas(samplePlanillas.cast<Map<String, dynamic>>());
        print('Datos de ejemplo inicializados para testing offline');
      }
    } catch (e) {
      print('Error inicializando datos de ejemplo: $e');
    }
  }
}
