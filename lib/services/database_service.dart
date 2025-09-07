import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vacunacion.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE perdidas_locales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cantidad INTEGER NOT NULL,
        lote_vacuna TEXT NOT NULL,
        motivo TEXT,
        fecha_perdida TEXT NOT NULL,
        latitud REAL,
        longitud REAL,
        foto_base64 TEXT,
        sincronizado INTEGER DEFAULT 0,
        uuid_local TEXT UNIQUE,
        fecha_registro TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE responsables_locales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL,
        finca TEXT NOT NULL,
        planilla_id INTEGER NOT NULL,
        zona TEXT,
        nombre_zona TEXT,
        lote_vacuna TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_registro TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mascotas_locales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        raza TEXT NOT NULL,
        color TEXT NOT NULL,
        antecedente_vacunal INTEGER DEFAULT 0,
        esterilizado INTEGER DEFAULT 0,
        responsable_local_id INTEGER,
        latitud REAL,
        longitud REAL,
        foto_base64 TEXT,
        sincronizado INTEGER DEFAULT 0,
        fecha_registro TEXT NOT NULL,
        FOREIGN KEY (responsable_local_id) REFERENCES responsables_locales(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS perdidas_locales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cantidad INTEGER NOT NULL,
          lote_vacuna TEXT NOT NULL,
          motivo TEXT,
          fecha_perdida TEXT NOT NULL,
          latitud REAL,
          longitud REAL,
          foto_base64 TEXT,
          sincronizado INTEGER DEFAULT 0,
          uuid_local TEXT UNIQUE,
          fecha_registro TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> guardarPerdidaLocal(Map<String, dynamic> perdida) async {
    final db = await database;
    perdida['fecha_registro'] = DateTime.now().toIso8601String();
    return await db.insert('perdidas_locales', perdida);
  }

  Future<List<Map<String, dynamic>>> obtenerPerdidasNoSincronizadas() async {
    final db = await database;
    return await db.query(
      'perdidas_locales',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
  }

  Future<int> marcarPerdidaComoSincronizada(String uuidLocal) async {
    final db = await database;
    return await db.update(
      'perdidas_locales',
      {'sincronizado': 1},
      where: 'uuid_local = ?',
      whereArgs: [uuidLocal],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerTodasLasPerdidas() async {
    final db = await database;
    return await db.query(
      'perdidas_locales',
      orderBy: 'fecha_registro DESC',
    );
  }

  Future<int> eliminarPerdidaLocal(int id) async {
    final db = await database;
    return await db.delete(
      'perdidas_locales',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> guardarResponsableLocal(Map<String, dynamic> responsable) async {
    final db = await database;
    responsable['fecha_registro'] = DateTime.now().toIso8601String();
    return await db.insert('responsables_locales', responsable);
  }

  Future<int> guardarMascotaLocal(Map<String, dynamic> mascota) async {
    final db = await database;
    mascota['fecha_registro'] = DateTime.now().toIso8601String();
    return await db.insert('mascotas_locales', mascota);
  }

  Future<List<Map<String, dynamic>>> obtenerResponsablesNoSincronizados() async {
    final db = await database;
    return await db.query(
      'responsables_locales',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerMascotasNoSincronizadas() async {
    final db = await database;
    return await db.query(
      'mascotas_locales',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
  }
}