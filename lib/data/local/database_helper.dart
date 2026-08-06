import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/attendance_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async =>
      _database ??= await _initDB('app_db_v2.db');

  Future<Database> _initDB(String filePath) async {
    return openDatabase(
      join(await getDatabasesPath(), filePath),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE attendance(
            id INTEGER PRIMARY KEY,
            subjectName TEXT,
            attended INTEGER,
            total INTEGER,
            percentage REAL,
            dailyStatus TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveAttendance(List<AttendanceModel> data) async {
    final db = await database;
    await db.delete('attendance');
    for (var item in data) {
      await db.insert('attendance', item.toMap());
    }
  }

  Future<List<AttendanceModel>> getCached() async {
    final db = await database;
    final res = await db.query('attendance');
    return res.map((j) => AttendanceModel.fromMap(j)).toList();
  }
}