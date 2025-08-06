class Item {
  final int? id;
  final String nombre;
  final DateTime creado;

  Item({this.id, required this.nombre, required this.creado});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    id: json['id'],
    nombre: json['nombre'],
    creado: DateTime.parse(json['creado']),
  );

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
  };
}
