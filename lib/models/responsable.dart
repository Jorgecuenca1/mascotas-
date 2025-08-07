// lib/models/responsable.dart
import 'mascota.dart';

class Responsable {
  final int id;
  final String nombre;
  final String telefono;
  final String finca;
  final String zona; // Nuevo campo: vereda, centro poblado, barrio
  final String nombreZona; // Nuevo campo: nombre de la zona
  final String loteVacuna; // Nuevo campo: lote de vacuna
  final DateTime creado;
  final List<Mascota> mascotas;

  Responsable({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.finca,
    required this.zona,
    required this.nombreZona,
    required this.loteVacuna,
    required this.creado,
    required this.mascotas,
  });

  factory Responsable.fromJson(Map<String, dynamic> json) => Responsable(
    id: json['id'] as int? ?? 0,
    nombre: json['nombre'] as String? ?? '',
    telefono: json['telefono'] as String? ?? '',
    finca: json['finca'] as String? ?? '',
    zona: json['zona'] as String? ?? 'vereda',
    nombreZona: json['nombre_zona'] as String? ?? '',
    loteVacuna: json['lote_vacuna'] as String? ?? '',
    creado: DateTime.tryParse(json['creado'] as String? ?? '') ?? DateTime.now(),
    mascotas: (json['mascotas'] as List<dynamic>?)
        ?.map((e) => Mascota.fromJson(e as Map<String, dynamic>))
        .toList() ?? <Mascota>[],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'finca': finca,
    'zona': zona,
    'nombre_zona': nombreZona,
    'lote_vacuna': loteVacuna,
    'creado': creado.toIso8601String(),
    'mascotas': mascotas.map((m) => m.toJson()).toList(),
  };

  // Opciones disponibles para el campo zona
  static const List<String> opcionesZona = [
    'vereda',
    'centro poblado', 
    'barrio',
  ];
} 