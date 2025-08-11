import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LocalMessageDB {
  static LocalMessageDB? _instance;
  static String? _currentUserId;
  final Database _db;

  LocalMessageDB._create(this._db);

  /// 获取当前 userId 对应的数据库实例（单例）
  static Future<LocalMessageDB> getInstance(String userId) async {
    if (_instance != null && _currentUserId == userId) {
      return _instance!;
    }
    if (_instance != null) {
      await _instance!._db.close();
      _instance = null;
    }
    _currentUserId = userId;

    final path = join(
      await getDatabasesPath(),
      'messages_${userId}.db',
    );
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            fromUserId TEXT,
            toUserId TEXT,
            type TEXT,
            content TEXT,
            status TEXT,
            createdAt TEXT,
            read INTEGER DEFAULT 0,
            extra TEXT
          )
        ''');
      },
    );

    _instance = LocalMessageDB._create(database);
    return _instance!;
  }

  /// 插入一条消息，已有主键则忽略
  Future<void> insertMessage(Map<String, dynamic> msg) async {
    String status = msg['status'] ?? 'info';
    final content = msg['content'] ?? '';

    if (status == 'info') {
      if (content.contains('确认')) {
        status = 'confirmed';
      } else if (content.contains('拒绝')) {
        status = 'rejected';
      }
    }

    // 将 extra 字段序列化为字符串保存
    String? extraJson;
    final extraRaw = msg['extra'];
    if (extraRaw != null) {
      try {
        extraJson = jsonEncode(extraRaw);
      } catch (_) {
        extraJson = null;
      }
    }

    await _db.insert(
      'messages',
      {
        'id': msg['_id'],
        'fromUserId': msg['fromUserId'] ?? '',
        'toUserId': msg['toUserId'] ?? '',
        'type': msg['type'] ?? 'system',
        'content': content,
        'status': status,
        'createdAt': msg['createdAt'] ?? DateTime.now().toIso8601String(),
        'read': 0,
        'extra': extraJson,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 查询所有消息（按时间倒序）
  Future<List<Map<String, dynamic>>> fetchAllMessages() async {
    return await _db.query(
      'messages',
      orderBy: 'createdAt DESC',
    );
  }

  /// 将指定消息标记为已读
  Future<void> markAsRead(String id) async {
    await _db.update(
      'messages',
      {'read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除指定消息，返回删除的行数
  Future<int> deleteMessageById(String id) async {
    return await _db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有消息
  Future<void> clearAll() async {
    await _db.delete('messages');
  }
}
