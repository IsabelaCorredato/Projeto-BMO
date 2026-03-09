import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

class ChatDatabase {
  static const _databaseName = 'bmo_context.db';
  static const _databaseVersion = 1;
  static const _tableMessages = 'messages';

  Database? _database;

  Future<void> init() async {
    if (_database != null) {
      return;
    }

    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableMessages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source TEXT NOT NULL,
            text TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<ChatMessage>> loadMessages({int limit = 80}) async {
    final db = _database;
    if (db == null) {
      throw StateError('Database is not initialized');
    }

    final rows = await db.query(
      _tableMessages,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<ChatMessage> insertMessage(ChatMessage message) async {
    final db = _database;
    if (db == null) {
      throw StateError('Database is not initialized');
    }

    final id = await db.insert(_tableMessages, message.toMap());
    return message.copyWith(id: id);
  }

  Future<void> clearAll() async {
    final db = _database;
    if (db == null) {
      throw StateError('Database is not initialized');
    }

    await db.delete(_tableMessages);
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
