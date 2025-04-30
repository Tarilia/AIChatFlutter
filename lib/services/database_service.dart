import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) '';
import '../models/message.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            model_id TEXT,
            tokens INTEGER,
            cost REAL
          )
        ''');

        await db.execute('''
          CREATE TABLE auth_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            api_key TEXT NOT NULL,
            pin_code TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Auth methods
  Future<void> saveAuthData(String apiKey, String pin) async {
    final db = await database;
    await db.delete('auth_data');
    await db.insert('auth_data', {
      'api_key': apiKey,
      'pin_code': pin,
    });
  }

  Future<String?> getApiKey() async {
    final db = await database;
    final result = await db.query('auth_data');
    return result.isNotEmpty ? result.first['api_key'] as String? : null;
  }

  Future<String?> getPin() async {
    final db = await database;
    final result = await db.query('auth_data');
    return result.isNotEmpty ? result.first['pin_code'] as String? : null;
  }

  Future<bool> hasPin() async {
    final pin = await getPin();
    return pin != null && pin.isNotEmpty;
  }

  Future<void> clearAuthData() async {
    final db = await database;
    await db.delete('auth_data');
  }

  // Message methods
  Future<void> saveMessage(ChatMessage message) async {
    try {
      final db = await database;
      await db.insert(
        'messages',
        {
          'content': message.content,
          'is_user': message.isUser ? 1 : 0,
          'timestamp': message.timestamp.toIso8601String(),
          'model_id': message.modelId,
          'tokens': message.tokens,
          'cost': message.cost,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<List<ChatMessage>> getMessages({int limit = 50}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        orderBy: 'timestamp ASC',
        limit: limit,
      );

      return List.generate(maps.length, (i) {
        return ChatMessage(
          content: maps[i]['content'] as String,
          isUser: maps[i]['is_user'] == 1,
          timestamp: DateTime.parse(maps[i]['timestamp'] as String),
          modelId: maps[i]['model_id'] as String?,
          tokens: maps[i]['tokens'] as int?,
          cost: maps[i]['cost'] as double?,
        );
      });
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final db = await database;
      await db.delete('messages');
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }
}
