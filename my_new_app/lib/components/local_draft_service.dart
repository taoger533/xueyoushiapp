import 'package:shared_preferences/shared_preferences.dart';

class LocalDraftService {
  final String userId;
  final String type; // student 或 teacher

  LocalDraftService({required this.userId, required this.type});

  String _key(String field) => 'draft_${type}_$field\_$userId';

  Future<void> save(Map<String, String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in fields.entries) {
      await prefs.setString(_key(entry.key), entry.value);
    }
  }

  /// 加载指定字段的草稿内容
  Future<Map<String, String>> load(List<String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, String>{};
    for (final field in fields) {
      result[field] = prefs.getString(_key(field)) ?? '';
    }
    return result;
  }

  /// 清除指定字段的草稿
  Future<void> clear(List<String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    for (final field in fields) {
      await prefs.remove(_key(field));
    }
  }

  /// 🚀 新增：加载所有草稿字段（自动识别已保存的字段）
  Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final result = <String, String>{};
    for (final key in allKeys) {
      final prefix = 'draft_${type}_';
      if (key.startsWith(prefix) && key.endsWith('_$userId')) {
        final field = key.substring(prefix.length, key.length - userId.length - 1);
        result[field] = prefs.getString(key) ?? '';
      }
    }
    return result;
  }
}
