// lib/screens/add_responsable_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/mascota.dart';
import '../services/responsable_service.dart';
import '../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AddResponsableScreen extends StatefulWidget {
  final int planillaId;
  const AddResponsableScreen({Key? key, required this.planillaId}) : super(key: key);

  @override
  _AddResponsableScreenState createState() => _AddResponsableScreenState();
}

class _AddResponsableScreenState extends State<AddResponsableScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Campos del responsable
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _fincaController = TextEditingController();
  
  // Campos de la mascota
  final _mascotaNombreController = TextEditingController();
  String _tipoSeleccionado = 'perro';
  String _razaSeleccionada = 'M';
  final _colorController = TextEditingController();
  bool _antecedenteVacunal = false;
  String? _fotoBase64;
  double? _latitud;
  double? _longitud;
  final ImagePicker _picker = ImagePicker();
  
  // Lista de mascotas a agregar
  List<Map<String, dynamic>> _mascotas = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _actualizarRazas();
  }

  void _actualizarRazas() {
    final razas = Mascota.getRazasPorTipo(_tipoSeleccionado);
    if (!razas.contains(_razaSeleccionada)) {
      _razaSeleccionada = razas.first;
    }
    setState(() {});
  }

  void _agregarMascota() {
    if (_mascotaNombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre de la mascota')),
      );
      return;
    }

    final mascota = {
      'nombre': _mascotaNombreController.text.trim(),
      'tipo': _tipoSeleccionado,
      'raza': _razaSeleccionada,
      'color': _colorController.text.trim(),
      'antecedente_vacunal': _antecedenteVacunal,
      if (_fotoBase64 != null) 'foto': _fotoBase64,
      if (_latitud != null) 'latitud': _latitud,
      if (_longitud != null) 'longitud': _longitud,
    };

    setState(() {
      _mascotas.add(mascota);
      _mascotaNombreController.clear();
      _colorController.clear();
      _antecedenteVacunal = false;
      _fotoBase64 = null;
      _latitud = null;
      _longitud = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mascota agregada a la lista')),
    );
  }

  void _tomarFoto() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );
      
      if (imagen != null) {
        final bytes = await imagen.readAsBytes();
        final base64String = base64Encode(bytes);
        
        setState(() {
          _fotoBase64 = base64String;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📷 Foto capturada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error capturando foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _obtenerUbicacion() async {
    try {
      // Simulamos obtener ubicación (puedes integrar geolocator después)
      await Future.delayed(const Duration(seconds: 1));
      
      // Coordenadas de ejemplo (Lima, Perú) con variación
      final lat = -12.0464 + (DateTime.now().millisecondsSinceEpoch % 1000) / 10000;
      final lng = -77.0428 + (DateTime.now().millisecondsSinceEpoch % 1000) / 10000;
      
      setState(() {
        _latitud = lat;
        _longitud = lng;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Ubicación obtenida'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error obteniendo ubicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _eliminarMascota(int index) {
    setState(() {
      _mascotas.removeAt(index);
    });
  }

  Future<void> _guardarResponsable() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mascotas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos una mascota')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultado = await ResponsableService.createResponsable(
        widget.planillaId,
        _nombreController.text.trim(),
        _telefonoController.text.trim(),
        _fincaController.text.trim(),
        _mascotas,
      );
      
      if (resultado != null) {
        // Se guardó exitosamente en el servidor
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Responsable y mascotas guardados en el servidor'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Se guardó offline exitosamente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Guardado offline exitosamente. Sincronice cuando tenga conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      Navigator.pop(context, true);
    } catch (e) {
      // Solo errores reales llegan aquí (parsing, servidor, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error real: $e'),
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
        title: const Text('Agregar Responsable'),
        actions: [
          if (_mascotas.isNotEmpty)
            Text('${_mascotas.length} mascota${_mascotas.length > 1 ? 's' : ''}'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección del Responsable
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Responsable',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Responsable *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fincaController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Finca/Establecimiento *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Sección de Mascota
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agregar Mascota',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mascotaNombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Mascota *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _tipoSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Tipo *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'perro', child: Text('Perro')),
                                DropdownMenuItem(value: 'gato', child: Text('Gato')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _tipoSeleccionado = value!;
                                  _actualizarRazas();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _razaSeleccionada,
                              decoration: const InputDecoration(
                                labelText: 'Raza *',
                                border: OutlineInputBorder(),
                              ),
                              items: Mascota.getRazasPorTipo(_tipoSeleccionado)
                                  .map((raza) => DropdownMenuItem(
                                        value: raza,
                                        child: Text(raza),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _razaSeleccionada = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Antecedente Vacunal'),
                        value: _antecedenteVacunal,
                        onChanged: (value) {
                          setState(() {
                            _antecedenteVacunal = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      
                      // Campo de Foto
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Foto de la Mascota (opcional)', 
                                 style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            if (_fotoBase64 != null) ...[
                              Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: MemoryImage(base64Decode(_fotoBase64!)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _tomarFoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Cambiar Foto'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _fotoBase64 = null);
                                    },
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: _tomarFoto,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Tomar Foto'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Campo de Ubicación
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ubicación GPS (opcional)', 
                                 style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 8),
                            if (_latitud != null && _longitud != null) ...[
                              Text('📍 Lat: ${_latitud!.toStringAsFixed(6)}'),
                              Text('📍 Lng: ${_longitud!.toStringAsFixed(6)}'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _obtenerUbicacion,
                                    icon: const Icon(Icons.my_location),
                                    label: const Text('Actualizar'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _latitud = null;
                                        _longitud = null;
                                      });
                                    },
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                onPressed: _obtenerUbicacion,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Obtener Ubicación'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _agregarMascota,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Mascota'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Lista de mascotas agregadas
              if (_mascotas.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mascotas Agregadas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(_mascotas.length, (index) {
                          final mascota = _mascotas[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                Icons.pets,
                                color: mascota['antecedente_vacunal'] == true ? Colors.green : Colors.orange,
                              ),
                              title: Text(mascota['nombre']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${mascota['tipo'].toUpperCase()} - ${mascota['raza']} - ${mascota['color']}'),
                                  if (mascota['foto'] != null) 
                                    Text('📷 Foto capturada', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                  if (mascota['latitud'] != null && mascota['longitud'] != null) 
                                    Text('📍 Lat: ${(mascota['latitud'] as double).toStringAsFixed(4)}, Lng: ${(mascota['longitud'] as double).toStringAsFixed(4)}', 
                                         style: TextStyle(color: Colors.green, fontSize: 12)),
                                ],
                              ),
                              isThreeLine: mascota['foto'] != null || (mascota['latitud'] != null && mascota['longitud'] != null),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _eliminarMascota(index),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Botón guardar
              ElevatedButton(
                onPressed: _isLoading ? null : _guardarResponsable,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Guardar Responsable y Mascotas'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _fincaController.dispose();
    _mascotaNombreController.dispose();
    _colorController.dispose();
    super.dispose();
  }
} 