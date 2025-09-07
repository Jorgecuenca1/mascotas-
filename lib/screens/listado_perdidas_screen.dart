import 'package:flutter/material.dart';
import '../services/perdidas_service.dart';
import '../services/database_service_web.dart';
import '../services/perdidas_sync_service.dart';
import '../services/connectivity_service.dart';
import 'registro_perdidas_screen.dart';

class ListadoPerdidasScreen extends StatefulWidget {
  const ListadoPerdidasScreen({Key? key}) : super(key: key);

  @override
  _ListadoPerdidasScreenState createState() => _ListadoPerdidasScreenState();
}

class _ListadoPerdidasScreenState extends State<ListadoPerdidasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final PerdidasSyncService _syncService = PerdidasSyncService();
  
  List<Map<String, dynamic>> _perdidasOnline = [];
  List<Map<String, dynamic>> _perdidasOffline = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasConnection = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _checkConnection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final hasConn = await _connectivityService.hasConnection();
    setState(() {
      _hasConnection = hasConn;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar pérdidas locales (offline)
      final perdidasLocales = await _databaseService.obtenerTodasLasPerdidas();
      
      // Separar sincronizadas y no sincronizadas
      _perdidasOffline = perdidasLocales.where((p) => 
        p['sincronizado'] == 0 || p['sincronizado'] == false
      ).toList();
      
      // Intentar cargar pérdidas online si hay conexión
      _hasConnection = await _connectivityService.hasConnection();
      if (_hasConnection) {
        try {
          _perdidasOnline = await PerdidasService.obtenerPerdidas();
        } catch (e) {
          print('Error cargando pérdidas online: $e');
          _perdidasOnline = [];
        }
      }
    } catch (e) {
      print('Error cargando datos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarPerdidas() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await _syncService.syncPendingData();
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronización completada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Widget _buildPerdidaCard(Map<String, dynamic> perdida, bool isOffline) {
    final fecha = perdida['fecha_perdida'] ?? perdida['fecha_registro'] ?? '';
    final sincronizado = perdida['sincronizado'] == 1 || perdida['sincronizado'] == true;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOffline && !sincronizado ? Colors.orange : Colors.green,
          child: Icon(
            isOffline && !sincronizado ? Icons.cloud_off : Icons.cloud_done,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Lote: ${perdida['lote_vacuna'] ?? 'Sin lote'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cantidad: ${perdida['cantidad'] ?? 0} vacunas'),
            Text('Fecha: $fecha'),
            if (perdida['motivo'] != null && perdida['motivo'].toString().isNotEmpty)
              Text('Motivo: ${perdida['motivo']}', 
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (isOffline && !sincronizado)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pendiente de sincronizar',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (perdida['latitud'] != null && perdida['longitud'] != null)
              const Icon(Icons.location_on, size: 20, color: Colors.blue),
            if (perdida['foto'] != null || perdida['foto_base64'] != null)
              const Icon(Icons.photo_camera, size: 20, color: Colors.grey),
          ],
        ),
        onTap: () {
          _mostrarDetallesPerdida(perdida, isOffline);
        },
      ),
    );
  }

  void _mostrarDetallesPerdida(Map<String, dynamic> perdida, bool isOffline) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles de Pérdida'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Lote', perdida['lote_vacuna'] ?? 'Sin lote'),
              _buildDetailRow('Cantidad', '${perdida['cantidad'] ?? 0} vacunas'),
              _buildDetailRow('Fecha de pérdida', perdida['fecha_perdida'] ?? 'No especificada'),
              _buildDetailRow('Fecha de registro', perdida['fecha_registro'] ?? 'No especificada'),
              if (perdida['motivo'] != null && perdida['motivo'].toString().isNotEmpty)
                _buildDetailRow('Motivo', perdida['motivo']),
              if (perdida['latitud'] != null && perdida['longitud'] != null)
                _buildDetailRow('Ubicación', 
                  'Lat: ${perdida['latitud']}\nLng: ${perdida['longitud']}'),
              if (isOffline)
                _buildDetailRow('Estado', 
                  (perdida['sincronizado'] == 1 || perdida['sincronizado'] == true) 
                    ? 'Sincronizado' : 'Pendiente de sincronizar'),
              if (perdida['registrado_por'] != null)
                _buildDetailRow('Registrado por', perdida['registrado_por'].toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado de Pérdidas'),
        backgroundColor: Colors.red.shade700,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.cloud),
              text: 'Sincronizadas (${_perdidasOnline.length})',
            ),
            Tab(
              icon: const Icon(Icons.cloud_off),
              text: 'Pendientes (${_perdidasOffline.length})',
            ),
          ],
        ),
        actions: [
          if (_perdidasOffline.isNotEmpty)
            IconButton(
              icon: _isSyncing 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
              onPressed: _isSyncing ? null : _sincronizarPerdidas,
              tooltip: 'Sincronizar pérdidas pendientes',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab de pérdidas sincronizadas
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _perdidasOnline.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _hasConnection ? Icons.inbox : Icons.cloud_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _hasConnection 
                                  ? 'No hay pérdidas sincronizadas'
                                  : 'Sin conexión al servidor',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _perdidasOnline.length,
                          itemBuilder: (context, index) {
                            return _buildPerdidaCard(_perdidasOnline[index], false);
                          },
                        ),
                ),
                // Tab de pérdidas offline/pendientes
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _perdidasOffline.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle,
                                size: 64,
                                color: Colors.green,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No hay pérdidas pendientes de sincronizar',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            if (_perdidasOffline.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                color: Colors.orange.shade100,
                                child: Row(
                                  children: [
                                    const Icon(Icons.info, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_perdidasOffline.length} pérdidas pendientes de sincronizar',
                                        style: const TextStyle(color: Colors.orange),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isSyncing ? null : _sincronizarPerdidas,
                                      icon: const Icon(Icons.sync, size: 16),
                                      label: const Text('Sincronizar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _perdidasOffline.length,
                                itemBuilder: (context, index) {
                                  return _buildPerdidaCard(_perdidasOffline[index], true);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegistroPerdidasScreen()),
          );
          _loadData(); // Recargar datos al volver
        },
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
        tooltip: 'Registrar nueva pérdida',
      ),
    );
  }
}