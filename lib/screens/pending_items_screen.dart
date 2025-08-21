import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';

class PendingItemsScreen extends StatefulWidget {
  @override
  _PendingItemsScreenState createState() => _PendingItemsScreenState();
}

class _PendingItemsScreenState extends State<PendingItemsScreen> {
  Map<String, dynamic> _pendingItems = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingItems();
  }

  Future<void> _loadPendingItems() async {
    setState(() => _loading = true);
    try {
      final items = await SyncService.getPendingItems();
      setState(() {
        _pendingItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando items pendientes: $e')),
      );
    }
  }

  Future<void> _syncNow() async {
    try {
      final result = await SyncService.syncAll();
      await _loadPendingItems(); // Recargar después de sincronizar
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sincronización completada: ${result['success']} exitosos, ${result['failed']} fallidos'
          ),
          backgroundColor: result['failed'] > 0 ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en sincronización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Items Pendientes'),
        actions: [
          if (_pendingItems['total'] > 0)
            IconButton(
              icon: Icon(Icons.sync),
              onPressed: _syncNow,
              tooltip: 'Sincronizar ahora',
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _pendingItems['total'] == 0
              ? _buildEmptyState()
              : _buildPendingItemsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'No hay items pendientes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Todos los datos están sincronizados',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingItemsList() {
    final responsables = _pendingItems['responsables'] as List<dynamic>;
    final mascotas = _pendingItems['mascotas'] as List<dynamic>;

    return RefreshIndicator(
      onRefresh: _loadPendingItems,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Resumen
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Pendientes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Responsables: ${responsables.length}'),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.pets, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Mascotas: ${mascotas.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Responsables pendientes
          if (responsables.isNotEmpty) ...[
            Text(
              'Responsables Pendientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            ...responsables.map((r) => _buildResponsableCard(r)).toList(),
            SizedBox(height: 16),
          ],

          // Mascotas pendientes
          if (mascotas.isNotEmpty) ...[
            Text(
              'Mascotas Pendientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            ...mascotas.map((m) => _buildMascotaCard(m)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsableCard(Map<String, dynamic> responsable) {
    final timestamp = DateTime.tryParse(responsable['timestamp'] ?? '');
    final mascotas = responsable['mascotas'] as List<dynamic>;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.people, color: Colors.white),
        ),
        title: Text(responsable['nombre'] ?? 'Sin nombre'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tel: ${responsable['telefono'] ?? 'N/A'}'),
            Text('Finca: ${responsable['finca'] ?? 'N/A'}'),
            Text('Mascotas: ${mascotas.length}'),
            if (timestamp != null)
              Text(
                'Creado: ${timestamp.toLocal().toString().substring(0, 16)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildMascotaCard(Map<String, dynamic> mascota) {
    final timestamp = DateTime.tryParse(mascota['timestamp'] ?? '');

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.pets, color: Colors.white),
        ),
        title: Text(mascota['nombre'] ?? 'Sin nombre'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Planilla ID: ${mascota['planId']}'),
            if (timestamp != null)
              Text(
                'Creado: ${timestamp.toLocal().toString().substring(0, 16)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}


