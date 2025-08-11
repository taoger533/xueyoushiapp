import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import 'local_message_db.dart';

class SystemMessagesWidget extends StatefulWidget {
  const SystemMessagesWidget({Key? key}) : super(key: key);

  @override
  _SystemMessagesWidgetState createState() => _SystemMessagesWidgetState();
}

class _SystemMessagesWidgetState extends State<SystemMessagesWidget> {
  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  LocalMessageDB? _localDb;

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  /// 从服务器拉取、插入本地后，刷新 UI 列表
  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    if (_userId == null) return;

    _localDb = await LocalMessageDB.getInstance(_userId!);

    try {
      final resp = await http.get(Uri.parse('$apiBase/api/messages/$_userId'));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        for (var msg in data) {
          await _localDb!.insertMessage(msg);
          await http.post(
            Uri.parse('$apiBase/api/messages/${msg['_id']}/confirm'),
          );
        }
      }
    } catch (e) {
      debugPrint('[离线模式] 系统消息加载失败: $e');
    }

    await _refreshMessages();
  }

  /// 重新从本地数据库读取消息并更新到可变列表
  Future<void> _refreshMessages() async {
    final rawList = await _localDb!.fetchAllMessages();
    final mutableList = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
    setState(() => _messages = mutableList);

    // 调试：打印第一条消息，查看 extra 格式
    if (_messages.isNotEmpty) {
      debugPrint('[DEBUG] 第一条消息：${jsonEncode(_messages.first)}');
    }
  }

  /// 弹窗确认删除，删除成功后调用 _refreshMessages()
  void _confirmDelete(int index) {
    final id = _messages[index]['id'] as String;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除本地系统消息'),
        content: const Text('确定删除这条系统消息？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final count = await _localDb!.deleteMessageById(id);
                if (count > 0) {
                  await _refreshMessages();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除失败，请检查数据库')),
                  );
                }
              } catch (e) {
                debugPrint('删除异常: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除失败，请检查数据库')),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('暂无系统消息')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];

        // —— 安全解析 extra 字段 —— 
        Map<String, dynamic> extra = {};
        final rawExtra = msg['extra'];
        if (rawExtra is Map<String, dynamic>) {
          extra = rawExtra;
        } else if (rawExtra is String) {
          try {
            extra = jsonDecode(rawExtra) as Map<String, dynamic>;
          } catch (_) {
            extra = {};
          }
        }
        // —— 解析完成 —— 

        Widget? statusIcon;
        if (msg['status'] == 'confirmed') {
          statusIcon = const Icon(Icons.check_circle, color: Colors.green);
        } else if (msg['status'] == 'rejected') {
          statusIcon = const Icon(Icons.cancel, color: Colors.red);
        }

        // 组装科目文本
        String subjectText = '';
        if (extra['subjects'] is List) {
          final List subs = extra['subjects']!;
          subjectText = subs
              .map((e) => '${e['phase'] ?? ''}${e['subject'] ?? ''}')
              .join('，');
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: const Text('系统消息'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg['content'] ?? ''),
                if (extra.isNotEmpty) ...[
                  if (extra['name'] != null)
                    Text('称呼：${extra['name']}'),
                  if (subjectText.isNotEmpty)
                    Text('科目：$subjectText'),
                  if (extra['phone'] != null)
                    Text('手机号：${extra['phone']}'),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusIcon != null) statusIcon,
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  tooltip: '删除消息',
                  onPressed: () => _confirmDelete(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
