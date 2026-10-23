import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('echoguard.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Creates the database file
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';

    // 1. Table for Emergency Contacts
    await db.execute('''
    CREATE TABLE contacts (
      id $idType,
      name $textType,
      phone $textType
    )
    ''');

    // 2. Table for Detection History
    await db.execute('''
    CREATE TABLE history (
      id $idType,
      event_type $textType,
      timestamp $textType,
      location $textType
    )
    ''');
  }

  // ==========================================
  // CONTACT METHODS
  // ==========================================
  Future<int> addContact(String name, String phone) async {
    final db = await instance.database;
    return await db.insert('contacts', {'name': name, 'phone': phone});
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    final db = await instance.database;
    return await db.query('contacts');
  }

  Future<int> deleteContact(int id) async {
    final db = await instance.database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // HISTORY METHODS
  // ==========================================
  Future<int> logEvent(String eventType, String location) async {
    final db = await instance.database;
    return await db.insert('history', {
      'event_type': eventType,
      'timestamp': DateTime.now().toIso8601String(),
      'location': location,
    });
  }
}