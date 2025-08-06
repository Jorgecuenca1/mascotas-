// al principio del archivo…
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/item.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _connected = true;
  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() => _connected = status != ConnectivityResult.none);
    });
    SyncService.startNetworkListener();
  }

  Future<void> _loadItems() async {
    try {
      final fetched = await ApiService.fetchItems();
      setState(() => _items = fetched);
    } catch (_) {}
  }

  Future<void> _addItem() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;

    if (_connected) {
      try {
        final nuevo = await ApiService.createItem(texto);
        setState(() => _items.add(nuevo));
      } catch (_) {
        _queueAndNotify(texto);
      }
    } else {
      _queueAndNotify(texto);
    }
    _ctrl.clear();
  }

  void _queueAndNotify(String nombre) {
    SyncService.queuItem(nombre);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardado offline; sincronizará luego')),
    );
  }

  Future<void> _syncNow() async {
    await SyncService.syncPending();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todos los pendientes fueron enviados')),
    );
    // opcional: refresca la lista desde el servidor
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mascotas'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Sin mascotas aún'))
                  : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_items[i].nombre),
                  subtitle: Text(
                    _items[i]
                        .creado
                        .toLocal()
                        .toString()
                        .split('.')[0],
                  ),
                ),
              ),
            ),

            // Campo de texto y botón Agregar
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Nueva mascota',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(_connected ? Icons.cloud_upload : Icons.cloud_off),
              label: Text(_connected ? 'Agregar online' : 'Agregar offline'),
              onPressed: _addItem,
            ),

            const SizedBox(height: 8),

            // NUEVO: Botón para forzar sincronización
            ElevatedButton(
              onPressed: _syncNow,
              child: const Text('Sincronizar ya'),
            ),

            // (Opcional) Texto/Capa extra si estás offline
            if (!_connected)
              TextButton(
                child: const Text('Ver pendientes'),
                onPressed: () {
                  // podrías navegar a una pantalla de detalle de la cola
                },
              ),
          ],
        ),
      ),
    );
  }
}
