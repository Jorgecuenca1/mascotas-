// lib/models/mascota.dart
class Mascota {
  final int id;
  final String nombre;
  final String tipo; // "perro" o "gato"
  final String raza; // "M", "H", "PME" para perros; "M", "H" para gatos
  final String color;
  final bool antecedenteVacunal;
  final int responsableId;
  final DateTime creado;
  final String? foto; // Foto en base64 para envío a Django
  final double? latitud; // Latitud separada
  final double? longitud; // Longitud separada

  Mascota({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.raza,
    required this.color,
    required this.antecedenteVacunal,
    required this.responsableId,
    required this.creado,
    this.foto,
    this.latitud,
    this.longitud,
  });

  factory Mascota.fromJson(Map<String, dynamic> json) => Mascota(
    id: json['id'] as int? ?? 0,
    nombre: json['nombre'] as String? ?? '',
    tipo: json['tipo'] as String? ?? 'perro',
    raza: json['raza'] as String? ?? 'M',
    color: json['color'] as String? ?? '',
    antecedenteVacunal: json['antecedente_vacunal'] as bool? ?? false,
    responsableId: json['responsable_id'] as int? ?? 0,
    creado: DateTime.tryParse(json['creado'] as String? ?? '') ?? DateTime.now(),
    foto: json['foto'] as String?,
    latitud: json['latitud'] != null ? (json['latitud'] as num).toDouble() : null,
    longitud: json['longitud'] != null ? (json['longitud'] as num).toDouble() : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo,
    'raza': raza,
    'color': color,
    'antecedente_vacunal': antecedenteVacunal,
    'responsable_id': responsableId,
    'creado': creado.toIso8601String(),
    if (foto != null) 'foto': foto,
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
  };

  // Método para envío a Django sin responsable_id
  Map<String, dynamic> toJsonForApi() => {
    'nombre': nombre,
    'tipo': tipo,
    'raza': raza,
    'color': color,
    'antecedente_vacunal': antecedenteVacunal,
    if (foto != null) 'foto': foto,
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
  };

  // Lista de razas disponibles según el tipo
  static List<String> getRazasPorTipo(String tipo) {
    if (tipo == 'perro') {
      return ['M', 'H', 'PME'];
    } else if (tipo == 'gato') {
      return ['M', 'H'];
    }
    return ['M'];
  }
} 