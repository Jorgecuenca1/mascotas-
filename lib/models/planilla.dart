// lib/models/planilla.dart
import 'responsable.dart';

class Planilla {
  final int id;
  final String nombre;
  final DateTime creada;
  final List<Responsable> responsables;

  Planilla({
    required this.id,
    required this.nombre,
    required this.creada,
    required this.responsables,
  });

  factory Planilla.fromJson(Map<String, dynamic> json) => Planilla(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    creada: DateTime.parse(json['creada'] as String),
    responsables: (json['responsables'] as List?)
        ?.map((e) => Responsable.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'creada': creada.toIso8601String(),
    'responsables': responsables.map((r) => r.toJson()).toList(),
  };
}
