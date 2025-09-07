// lib/screens/planilla_list_screen.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/planilla.dart';
import '../services/planilla_service.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/responsable_service.dart';
import 'planilla_detail_screen.dart';
import 'login_screen.dart';
import 'pending_items_screen.dart';
import 'statistics_screen.dart';
import 'registro_perdidas_screen.dart';
import 'listado_perdidas_screen.dart';

class PlanillaListScreen extends StatefulWidget {
  @override _PlanillaListScreenState createState() => _PlanillaListScreenState();
}

class _PlanillaListScreenState extends State<PlanillaListScreen> {
  List<Planilla> _lista = [];
  bool _loading = true;
  bool _isOnline = true;
  String? _username;
  String? _userType;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadUsername();
    _loadPlanillas();
    
    // Escuchar cambios de conectividad
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
      if (_isOnline && _lista.isEmpty) {
        _loadPlanillas(); // Recargar si vuelve la conexión
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivity != ConnectivityResult.none;
    });
  }

  Future<void> _loadUsername() async {
    final username = await AuthService.savedUsername;
    final userType = await AuthService.userType;
    setState(() {
      _username = username;
      _userType = userType;
    });
  }

  Future<void> _loadPlanillas() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Inicializar datos de ejemplo si no hay datos offline
      await PlanillaService.initializeSampleData();
      
      // Usar el nuevo servicio mejorado que maneja online/offline automáticamente
      final planillas = await PlanillaService.fetchPlanillas();
      
      setState(() {
        _lista = planillas;
        _loading = false;
        if (planillas.isEmpty) {
          _errorMessage = _isOnline 
            ? 'No hay municipios disponibles en el servidor.'
            : 'Sin conexión y no hay datos guardados. Conéctate a internet para descargar los municipios.';
        }
      });
      
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = _isOnline 
          ? 'Error del servidor: $e'
          : 'Error cargando datos offline: $e';
      });
    }
  }

  Future<void> _logout({bool keepCredentials = true}) async {
    final String title = keepCredentials ? 'Cerrar Sesión' : 'Borrar Todos los Datos';
    final String message = keepCredentials 
        ? '¿Cerrar sesión? (Las credenciales se guardarán para login offline)'
        : '¿Borrar TODOS los datos incluyendo credenciales guardadas?';
    final String confirmText = keepCredentials ? 'Cerrar Sesión' : 'Borrar Todo';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: keepCredentials ? Colors.orange : Colors.red,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (keepCredentials) {
        await AuthService.logout(); // Logout suave
      } else {
        await AuthService.logoutCompletely(); // Logout completo
      }
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Estado de Conexión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: ${_isOnline ? "Conectado" : "Sin conexión"}'),
            SizedBox(height: 8),
            Text('Usuario: ${_username ?? "No disponible"}'),
            SizedBox(height: 8),
            Text(_isOnline 
              ? 'Los datos se sincronizan automáticamente con el servidor.'
              : 'Trabajando en modo offline. Los cambios se sincronizarán cuando vuelva la conexión.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeSampleData() async {
    try {
      await PlanillaService.initializeSampleData();
      _loadPlanillas();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Datos de prueba cargados correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _syncPendingData() async {
    try {
      setState(() => _loading = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Iniciando sincronización...'),
          backgroundColor: Colors.blue,
        ),
      );

      final result = await SyncService.syncAll();
      
      final success = result['success'] as int;
      final failed = result['failed'] as int;
      final errors = result['errors'] as List<String>;
      
      String message;
      Color color;
      
      if (success > 0 && failed == 0) {
        message = '✅ $success elementos sincronizados exitosamente';
        color = Colors.green;
      } else if (success > 0 && failed > 0) {
        message = '⚠️ $success exitosos, $failed fallidos';
        color = Colors.orange;
      } else if (failed > 0) {
        message = '❌ $failed elementos fallaron';
        color = Colors.red;
      } else {
        message = '📭 No hay elementos pendientes para sincronizar';
        color = Colors.grey;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: Duration(seconds: 4),
        ),
      );
      
      // Mostrar errores detallados si los hay
      if (errors.isNotEmpty) {
        _showSyncErrors(errors);
      }
      
      // Recargar planillas si hubo sincronización exitosa
      if (success > 0) {
        _loadPlanillas();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en sincronización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSyncErrors(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Errores de Sincronización'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Los siguientes elementos no se pudieron sincronizar:'),
              SizedBox(height: 12),
              Container(
                constraints: BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: errors.map((error) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $error',
                        style: TextStyle(fontSize: 12),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _testDjangoConnection() async {
    try {
      setState(() => _loading = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Probando conexión con Django...'),
          backgroundColor: Colors.blue,
        ),
      );

      final result = await ResponsableService.testConnection();
      
      final success = result['success'] as bool;
      final message = result['message'] as String;
      final details = result['details'] as Map<String, dynamic>;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text('Test de Conexión'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 12),
              Text('Detalles:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              ...details.entries.map((entry) => Text(
                '${entry.key}: ${entry.value}',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error probando conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userType == 'administrador' 
          ? 'Todos los Municipios (Admin)'
          : _userType == 'tecnico'
            ? 'Municipios - Técnico'
            : 'Mis Municipios'),
        actions: [
          // Indicador de conexión
          GestureDetector(
            onTap: _showConnectionInfo,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    color: _isOnline ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: _isOnline ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botón de estadísticas - solo para técnicos y administradores
          if (_userType == 'tecnico' || _userType == 'administrador') 
            IconButton(
              icon: Icon(Icons.bar_chart, color: Colors.green),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => StatisticsScreen()),
                );
              },
              tooltip: 'Ver Estadísticas',
            ),
          // Botón de actualizar - para todos
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPlanillas,
            tooltip: 'Actualizar',
          ),
          // Botón de sincronización - para todos
          IconButton(
            icon: Icon(Icons.sync, color: Colors.blue),
            onPressed: _syncPendingData,
            tooltip: 'Sincronizar Pendientes',
          ),
          // Botón de items pendientes - para todos
          IconButton(
            icon: Icon(Icons.pending_actions, color: Colors.orange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PendingItemsScreen()),
              );
            },
            tooltip: 'Ver Items Pendientes',
          ),
          // Menú de opciones - Solo mostrar cerrar sesión para vacunadores
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _logout(keepCredentials: true);
                  break;
                case 'logout_complete':
                  _logout(keepCredentials: false);
                  break;
                case 'init_sample':
                  _initializeSampleData();
                  break;
                case 'test_connection':
                  _testDjangoConnection();
                  break;
                case 'info':
                  _showConnectionInfo();
                  break;
                case 'registro_perdidas':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ListadoPerdidasScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) {
              List<PopupMenuItem<String>> menuItems = [
                // Cerrar sesión para todos
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Cerrar Sesión'),
                    ],
                  ),
                ),
                // Info de conexión para todos
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Info de Conexión'),
                    ],
                  ),
                ),
              ];
              
              // Opciones adicionales solo para administradores
              if (_userType == 'administrador') {
                menuItems.addAll([
                  PopupMenuItem(
                    value: 'logout_complete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Borrar Todo', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'init_sample',
                    child: Row(
                      children: [
                        Icon(Icons.data_array, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Cargar Datos de Prueba'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'test_connection',
                    child: Row(
                      children: [
                        Icon(Icons.network_check, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Probar Django'),
                      ],
                    ),
                  ),
                ]);
              }
              
              // Opciones para vacunadores - agregar Registro de Pérdidas
              if (_userType == 'vacunador') {
                menuItems.add(
                  PopupMenuItem(
                    value: 'registro_perdidas',
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Registro de Pérdidas'),
                      ],
                    ),
                  ),
                );
              }
              
              // Opciones para técnicos (pueden tener opciones adicionales aquí si es necesario)
              if (_userType == 'tecnico') {
                menuItems.addAll([
                  PopupMenuItem(
                    value: 'registro_perdidas',
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Registro de Pérdidas'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'test_connection',
                    child: Row(
                      children: [
                        Icon(Icons.network_check, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Probar Django'),
                      ],
                    ),
                  ),
                ]);
              }
              
              return menuItems;
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando municipios...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPlanillas,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No hay municipios disponibles',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlanillas,
              child: Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Mensaje informativo si está offline
        if (!_isOnline)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo offline: Mostrando datos guardados',
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        
        // Lista de planillas
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPlanillas,
            child: ListView.builder(
        itemCount: _lista.length,
              itemBuilder: (context, index) {
                final planilla = _lista[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        planilla.nombre.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(planilla.nombre),
                    subtitle: Text('${planilla.responsables.length} responsables'),
                    trailing: Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                        builder: (_) => PlanillaDetailScreen(plan: planilla),
                      ),
              ),
            ),
          );
        },
      ),
          ),
        ),
      ],
    );
  }
}
