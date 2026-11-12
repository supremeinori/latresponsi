import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AuthDatabase {
  Future<UserModel> registerUser({
    required String name,
    required String username,
    required String password,
  });

  Future<UserModel?> authenticateUser({
    required String username,
    required String password,
  });
}

class LocalDbService implements AuthDatabase {
  LocalDbService({this._prefs});

  static const String _dbName = 'rick_morty_explorer.db';
  static const String _tableUsers = 'users';
  static const String _webUsersKey = 'local_db_users_v1';

  Database? _database;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Database> _getDb() async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableUsers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  String _normalizeUsername(String username) => username.trim().toLowerCase();

  String _hashPassword(String normalizedUsername, String password) {
    final bytes = utf8.encode('$normalizedUsername:$password');
    return sha256.convert(bytes).toString();
  }

  @override
  Future<UserModel> registerUser({
    required String name,
    required String username,
    required String password,
  }) async {
    final cleanName = name.trim();
    final normalizedUsername = _normalizeUsername(username);
    if (cleanName.isEmpty || normalizedUsername.isEmpty || password.isEmpty) {
      throw const AuthException('Semua kolom wajib diisi.');
    }

    final passwordHash = _hashPassword(normalizedUsername, password);
    final createdAt = DateTime.now().toIso8601String();

    if (kIsWeb) {
      final prefs = await _getPrefs();
      final users = _readWebUsers(prefs);
      final exists = users.any((u) => u['username'] == normalizedUsername);
      if (exists) {
        throw const AuthException('Username sudah terdaftar. Gunakan username lain.');
      }
      final nextId = users.isEmpty
          ? 1
          : users
                  .map((u) => (u['id'] as num?)?.toInt() ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      final newUser = <String, dynamic>{
        'id': nextId,
        'name': cleanName,
        'username': normalizedUsername,
        'password_hash': passwordHash,
        'created_at': createdAt,
      };
      users.add(newUser);
      await prefs.setString(_webUsersKey, jsonEncode(users));
      return UserModel(id: nextId, name: cleanName, username: normalizedUsername);
    }

    final db = await _getDb();
    final existing = await db.query(
      _tableUsers,
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [normalizedUsername],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const AuthException('Username sudah terdaftar. Gunakan username lain.');
    }

    final id = await db.insert(_tableUsers, {
      'name': cleanName,
      'username': normalizedUsername,
      'password_hash': passwordHash,
      'created_at': createdAt,
    });

    return UserModel(id: id, name: cleanName, username: normalizedUsername);
  }

  @override
  Future<UserModel?> authenticateUser({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = _normalizeUsername(username);
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return null;
    }

    final passwordHash = _hashPassword(normalizedUsername, password);

    if (kIsWeb) {
      final prefs = await _getPrefs();
      final users = _readWebUsers(prefs);
      for (final user in users) {
        if (user['username'] == normalizedUsername &&
            user['password_hash'] == passwordHash) {
          return UserModel.fromMap(user);
        }
      }
      return null;
    }

    final db = await _getDb();
    final rows = await db.query(
      _tableUsers,
      columns: ['id', 'name', 'username'],
      where: 'username = ? AND password_hash = ?',
      whereArgs: [normalizedUsername, passwordHash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  List<Map<String, dynamic>> _readWebUsers(SharedPreferences prefs) {
    final raw = prefs.getString(_webUsersKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
