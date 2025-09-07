// lib/screens/add_responsable_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:geolocator/geolocator.dart';
import '../models/mascota.dart';
import '../services/responsable_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
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
  String _zonaSeleccionada = 'vereda'; // Nuevo campo
  final _nombreZonaController = TextEditingController(); // Nuevo campo
  final _loteVacunaController = TextEditingController(); // Nuevo campo
  
  // Campos de la mascota
  final _mascotaNombreController = TextEditingController();
  String _tipoSeleccionado = 'perro';
  String _razaSeleccionada = 'M';
  final _colorController = TextEditingController();
  bool _antecedenteVacunal = false;
  bool _esterilizado = false;
  String? _fotoBase64;
  double? _latitud;
  double? _longitud;
  final ImagePicker _picker = ImagePicker();
  
  // Lista de mascotas a agregar
  List<Map<String, dynamic>> _mascotas = [];
  bool _isLoading = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  String _speechPrev = '';

  String _dedupeWords(String input, {bool nonAdjacent = false}) {
    final parts = input.split(RegExp(r'\s+'));
    final List<String> out = [];
    final Set<String> seen = <String>{};
    for (final raw in parts) {
      final w = raw.trim();
      if (w.isEmpty) continue;
      final lower = w.toLowerCase();
      if (nonAdjacent) {
        if (seen.contains(lower)) continue;
        seen.add(lower);
        out.add(w);
      } else {
        if (out.isEmpty || out.last.toLowerCase() != lower) {
          out.add(w);
        }
      }
    }
    return out.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _actualizarRazas();
    _cargarDefaultsZona();
  }

  Future<void> _cargarDefaultsZona() async {
    final username = await AuthService.savedUsername;
    if (username == null) return;
    final defaults = await LocalStorageService.getZonaDefaults(username);
    if (defaults != null) {
      setState(() {
        _zonaSeleccionada = defaults['tipo_zona'] ?? _zonaSeleccionada;
        _nombreZonaController.text = defaults['nombre_zona'] ?? _nombreZonaController.text;
        _loteVacunaController.text = defaults['lote_vacuna'] ?? _loteVacunaController.text;
      });
    }
  }

  void _actualizarRazas() {
    final razas = Mascota.getRazasPorTipo(_tipoSeleccionado);
    if (!razas.contains(_razaSeleccionada)) {
      _razaSeleccionada = razas.first;
    }
    setState(() {});
  }

  Future<void> _toggleDictado(TextEditingController controller) async {
    if (!_listening) {
      final available = await _speech.initialize(
        onStatus: (s) {},
        onError: (e) {},
      );
      if (!available) return;
      setState(() => _listening = true);
      _speechPrev = '';
      await _speech.listen(
        onResult: (res) {
          final recognized = res.recognizedWords.trim();
          if (recognized.isEmpty) return;

          // Calcula solo el delta para evitar repeticiones de parciales
          String delta;
          if (recognized.toLowerCase().startsWith(_speechPrev.toLowerCase())) {
            delta = recognized.substring(_speechPrev.length);
          } else {
            // Fallback: si no hay prefijo común, evita duplicar si es igual a lo previo
            if (recognized.toLowerCase() == _speechPrev.toLowerCase()) {
              delta = '';
            } else {
              delta = recognized;
            }
          }

          if (delta.isNotEmpty) {
            final current = controller.text.trim();
            final appended = current.isEmpty ? delta : '$current ${delta.trimLeft()}';
            final newText = _dedupeWords(appended, nonAdjacent: true);
            controller.text = newText;
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }

          _speechPrev = recognized;

          if (res.finalResult) {
            _speech.stop();
            setState(() => _listening = false);
          }
        },
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        localeId: null,
      );
    } else {
      await _speech.stop();
      setState(() => _listening = false);
    }
  }

  void _agregarMascota() async {
    if (_mascotaNombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre de la mascota')),
      );
      return;
    }

    // Si no hay ubicación, obtenerla automáticamente
    double? latitudFinal = _latitud;
    double? longitudFinal = _longitud;
    
    if (latitudFinal == null || longitudFinal == null) {
      try {
        // Intentar obtener ubicación automáticamente
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          
          if (permission == LocationPermission.always || 
              permission == LocationPermission.whileInUse) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            // Usar 6 decimales de precisión
            latitudFinal = double.parse(position.latitude.toStringAsFixed(6));
            longitudFinal = double.parse(position.longitude.toStringAsFixed(6));
            print('Ubicación obtenida automáticamente: $latitudFinal, $longitudFinal');
          }
        }
      } catch (e) {
        print('No se pudo obtener ubicación automática: $e');
      }
    }

    final mascota = {
      'nombre': _mascotaNombreController.text.trim(),
      'tipo': _tipoSeleccionado,
      'raza': _razaSeleccionada,
      'color': _colorController.text.trim(),
      'antecedente_vacunal': _antecedenteVacunal,
      'esterilizado': _esterilizado,
      if (_fotoBase64 != null) 'foto': _fotoBase64,
      if (latitudFinal != null) 'latitud': latitudFinal,
      if (longitudFinal != null) 'longitud': longitudFinal,
    };

    setState(() {
      _mascotas.add(mascota);
      _mascotaNombreController.clear();
      _colorController.clear();
      _antecedenteVacunal = false;
      _esterilizado = false;
      _fotoBase64 = null;
      _latitud = null;
      _longitud = null;
    });

    String mensaje = 'Mascota agregada a la lista';
    if (latitudFinal != null && longitudFinal != null && _latitud == null) {
      mensaje += ' (con ubicación automática)';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
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
      // Verificar permisos primero
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Por favor, activa los servicios de ubicación'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Permisos de ubicación denegados'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Los permisos de ubicación están permanentemente denegados'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Obtener la posición actual con alta precisión
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Redondear a 6 decimales
      double lat = double.parse(position.latitude.toStringAsFixed(6));
      double lng = double.parse(position.longitude.toStringAsFixed(6));
      
      setState(() {
        _latitud = lat;
        _longitud = lng;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Ubicación obtenida: $lat, $lng'),
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
        const SnackBar(
          content: Text('⚠️ Debe agregar al menos una mascota a la lista antes de guardar el responsable'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Guardar defaults inmediatamente (antes o después del envío)
      final username = await AuthService.savedUsername;
      if (username != null) {
        await LocalStorageService.saveZonaDefaults(
          username: username,
          tipoZona: _zonaSeleccionada,
          nombreZona: _nombreZonaController.text.trim(),
          loteVacuna: _loteVacunaController.text.trim(),
        );
      }

      final resultado = await ResponsableService.createResponsable(
        widget.planillaId,
        _nombreController.text.trim(),
        _telefonoController.text.trim(),
        _fincaController.text.trim(),
        _zonaSeleccionada,
        _nombreZonaController.text.trim(),
        _loteVacunaController.text.trim(),
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
        // Se guardó offline exitosamente (sin lanzar excepciones)
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
                        decoration: InputDecoration(
                          labelText: 'Nombre del Responsable *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            onPressed: () => _toggleDictado(_nombreController),
                          ),
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
                        decoration: InputDecoration(
                          labelText: 'Teléfono *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            onPressed: () => _toggleDictado(_telefonoController),
                          ),
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
                        decoration: InputDecoration(
                          labelText: 'Nombre de la Finca/Establecimiento *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            onPressed: () => _toggleDictado(_fincaController),
                          ),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _zonaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Zona *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'vereda', child: Text('Vereda')),
                          DropdownMenuItem(value: 'centro poblado', child: Text('Centro Poblado')),
                          DropdownMenuItem(value: 'barrio', child: Text('Barrio')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _zonaSeleccionada = value!;
                          });
                        },
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Campo requerido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreZonaController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la Zona *',
                          border: const OutlineInputBorder(),
                          hintText: 'Ej: La Esperanza, San Juan, etc.',
                          suffixIcon: IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            onPressed: () => _toggleDictado(_nombreZonaController),
                          ),
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
                        controller: _loteVacunaController,
                        decoration: InputDecoration(
                          labelText: 'Lote de Vacuna *',
                          border: const OutlineInputBorder(),
                          hintText: 'Ej: LT001, VAC2023-001, etc.',
                          suffixIcon: IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                            onPressed: () => _toggleDictado(_loteVacunaController),
                          ),
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
                        'Datos de la Mascota',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Llene los datos y presione "Agregar Mascota a la Lista" para cada mascota',
                                style: TextStyle(color: Colors.blue, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
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
                      CheckboxListTile(
                        title: const Text('Esterilizado'),
                        value: _esterilizado,
                        onChanged: (value) {
                          setState(() {
                            _esterilizado = value ?? false;
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
                        label: const Text('Agregar Mascota a la Lista'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
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