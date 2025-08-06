// lib/screens/planilla_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/planilla.dart';
import '../models/responsable.dart';
import '../models/mascota.dart';
import '../services/responsable_service.dart';
import '../services/sync_service.dart';
import '../services/local_storage_service.dart';
import 'add_responsable_screen.dart';

class PlanillaDetailScreen extends StatefulWidget {
  final Planilla plan;
  const PlanillaDetailScreen({Key? key, required this.plan}) : super(key: key);

  @override
  _PlanillaDetailScreenState createState() => _PlanillaDetailScreenState();
}

class _PlanillaDetailScreenState extends State<PlanillaDetailScreen> {
  List<Responsable> _responsables = [];
  List<Map<String, dynamic>> _pendingResponsables = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    SyncService.startNetworkListener();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Cargar responsables del servidor
      final responsables = await ResponsableService.fetchResponsables(widget.plan.id);
      setState(() => _responsables = responsables);
      
      // Cargar responsables pendientes
      final pending = await LocalStorageService.getPendingResponsables();
      setState(() => _pendingResponsables = pending);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando datos: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navegar a pantalla para agregar responsable
  Future<void> _agregarResponsable() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddResponsableScreen(planillaId: widget.plan.id),
      ),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  /// Sincronizar pendientes
  Future<void> _enviarPendientes() async {
    setState(() => _isLoading = true);
    try {
      await SyncService.syncAll();
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
          content: Text('Error sincronizando: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.nombre),
        actions: [
          if (_pendingResponsables.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_pendingResponsables.length} pendientes',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Lista de responsables
                  Expanded(
                    child: _responsables.isEmpty && _pendingResponsables.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No hay responsables aún',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Toca el botón + para agregar un responsable',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            children: [
                              // Responsables del servidor
                              if (_responsables.isNotEmpty) ...[
                                const Text(
                                  'Responsables Guardados',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ..._responsables.map((responsable) => _buildResponsableCard(responsable, false)),
                                const SizedBox(height: 16),
                              ],
                              
                              // Responsables pendientes
                              if (_pendingResponsables.isNotEmpty) ...[
                                const Text(
                                  'Pendientes de Sincronizar',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                                const SizedBox(height: 8),
                                ..._pendingResponsables.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final responsable = entry.value;
                                  return _buildPendingResponsableCard(responsable, index);
                                }),
                              ],
                            ],
                          ),
                  ),

                  // Botón sincronizar
                  if (_pendingResponsables.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _enviarPendientes,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sincronizar pendientes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarResponsable,
        child: const Icon(Icons.add),
        tooltip: 'Agregar Responsable',
      ),
    );
  }

  Widget _buildResponsableCard(Responsable responsable, bool isPending) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.person),
        title: Text(responsable.nombre),
        subtitle: Text('${responsable.finca} - ${responsable.telefono}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mascotas (${responsable.mascotas.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...responsable.mascotas.map((mascota) => ListTile(
                  leading: Icon(
                    Icons.pets,
                    color: mascota.antecedenteVacunal ? Colors.green : Colors.orange,
                  ),
                  title: Text(mascota.nombre),
                  subtitle: Text(
                    '${mascota.tipo.toUpperCase()} - ${mascota.raza} - ${mascota.color}',
                  ),
                  trailing: mascota.antecedenteVacunal
                      ? const Icon(Icons.vaccines, color: Colors.green)
                      : const Icon(Icons.warning, color: Colors.orange),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingResponsableCard(Map<String, dynamic> responsable, int index) {
    final mascotas = responsable['mascotas'] as List<dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange.shade50,
      child: ExpansionTile(
        leading: const Icon(Icons.person, color: Colors.orange),
        title: Text(responsable['nombre'] ?? ''),
        subtitle: Text('${responsable['finca'] ?? ''} - ${responsable['telefono'] ?? ''}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removePendingResponsable(index),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mascotas (${mascotas.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...mascotas.map((mascota) => ListTile(
                  leading: Icon(
                    Icons.pets,
                    color: (mascota['antecedente_vacunal'] == true) ? Colors.green : Colors.orange,
                  ),
                  title: Text(mascota['nombre'] ?? ''),
                  subtitle: Text(
                    '${(mascota['tipo'] ?? '').toUpperCase()} - ${mascota['raza'] ?? ''} - ${mascota['color'] ?? ''}',
                  ),
                  trailing: (mascota['antecedente_vacunal'] == true)
                      ? const Icon(Icons.vaccines, color: Colors.green)
                      : const Icon(Icons.warning, color: Colors.orange),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removePendingResponsable(int index) async {
    await LocalStorageService.removePendingResponsable(index);
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Responsable pendiente eliminado')),
    );
  }
}
