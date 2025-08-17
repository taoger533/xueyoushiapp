import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import 'local_message_db.dart';

class SystemMessagesWidget extends StatefulWidget {
  const SystemMessagesWidget({
    Key? key,
    this.onUnreadChanged,
  }) : super(key: key);

  /// 未读数变化回调（用于顶部红点）
  final ValueChanged<int>? onUnreadChanged;

  @override
  SystemMessagesWidgetState createState() => SystemMessagesWidgetState();
}

class SystemMessagesWidgetState extends State<SystemMessagesWidget> {
  List<Map<String, dynamic>> _messages = [];
  String? _userId;
  LocalMessageDB? _localDb;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// 暴露给父组件的刷新方法（拉取 + 回填 + 读本地）
  Future<void> refresh() async {
    await _loadAndFetch();
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
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        for (final msg in data) {
          final mapMsg = (msg is Map)
              ? Map<String, dynamic>.from(msg as Map)
              : <String, dynamic>{};
          await _localDb!.insertMessage(mapMsg);
          // 拉取到即回执确认
          await http.post(
            Uri.parse('$apiBase/api/messages/${mapMsg['_id']}/confirm'),
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
    if (_localDb == null) return;
    final rawList = await _localDb!.fetchAllMessages();
    final mutableList =
        rawList.map((e) => Map<String, dynamic>.from(e)).toList();

    setState(() => _messages = mutableList);

    // 计算未读数并通知父组件
    final unread = _calcUnread(mutableList);
    widget.onUnreadChanged?.call(unread);

    // 调试：打印第一条消息，查看 extra 格式
    if (_messages.isNotEmpty) {
      debugPrint('[DEBUG] 第一条消息：${jsonEncode(_messages.first)}');
    }
  }

  /// 计算未读：优先看 read 字段；若无则把 status == 'unread' 视为未读
  int _calcUnread(List<Map<String, dynamic>> list) {
    int cnt = 0;
    for (final m in list) {
      if (_isUnread(m)) cnt++;
    }
    return cnt;
  }

  bool _isUnread(Map<String, dynamic> m) {
    final read = m['read'];
    if (read is bool) return !read;
    final status = (m['status'] as String?) ?? '';
    return status == 'unread';
  }

  /// 弹窗确认删除，删除成功后调用 _refreshMessages()
  void _confirmDelete(int index) {
    final id = _messages[index]['id'] as String? ??
        _messages[index]['_id'] as String? ??
        '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除本地系统消息'),
        content: const Text('确定删除这条系统消息？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (id.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除失败：缺少消息ID')),
                  );
                  return;
                }
                final count = await _localDb!.deleteMessageById(id);
                if (count > 0) {
                  await _refreshMessages();
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('删除失败，请检查数据库')),
                  );
                }
              } catch (e) {
                debugPrint('删除异常: $e');
                if (!mounted) return;
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

  /// 未读红点
  Widget _unreadDot() {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 8, top: 2),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // —— 空列表：支持下拉刷新 & 居中文字 ——
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            SliverFillRemaining(
              hasScrollBody: false,        // 关键：让子组件占满整个可视区域
              child: Center(
                child: Text(
                  '暂时没有系统消息',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }


    // —— 非空列表：支持下拉刷新 + 未读红点 ——
    return RefreshIndicator(
      onRefresh: refresh, // 改为完整刷新流程（含拉取 + 回填 + 读本地）
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final msg = _messages[i];

          // —— 安全解析 extra 字段 ——
          Map<String, dynamic> extra = {};
          final rawExtra = msg['extra'];
          if (rawExtra is Map) {
            extra = Map<String, dynamic>.from(rawExtra);
          } else if (rawExtra is String) {
            try {
              final decoded = jsonDecode(rawExtra);
              if (decoded is Map) {
                extra = Map<String, dynamic>.from(decoded);
              }
            } catch (_) {
              extra = {};
            }
          }
          // —— 解析完成 ——

          final isUnread = _isUnread(msg);

          Widget? statusIcon;
          if (msg['status'] == 'confirmed' || msg['read'] == true) {
            statusIcon = const Icon(Icons.check_circle, color: Colors.green);
          } else if (msg['status'] == 'rejected') {
            statusIcon = const Icon(Icons.cancel, color: Colors.red);
          }

          // 组装科目文本
          String subjectText = '';
          final subjects = (extra['subjects'] is List)
              ? (extra['subjects'] as List)
              : const [];
          if (subjects.isNotEmpty) {
            subjectText = subjects
                .map((e) {
                  if (e is Map) {
                    final m = Map<String, dynamic>.from(e);
                    final phase = (m['phase'] as String?) ?? '';
                    final subject = (m['subject'] as String?) ?? '';
                    return '$phase$subject';
                  }
                  return '';
                })
                .where((s) => s.isNotEmpty)
                .join('，');
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: isUnread ? _unreadDot() : const SizedBox(width: 10),
              title: const Text('系统消息'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg['content'] ?? ''),
                  if (extra.isNotEmpty) ...[
                    if (extra['name'] != null) Text('称呼：${extra['name']}'),
                    if (subjectText.isNotEmpty) Text('科目：$subjectText'),
                    // 根据 needMembership 字段决定显示提示还是手机号
                    if (extra['needMembership'] == true)
                      const Text('您当前不是会员，暂时无法查看联系方式，请开通会员后再查看。')
                    else if (extra['phone'] != null)
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
              // 可选：点击后把当前项当作“已读”的即时 UI 反馈（仅前端状态，不改本地库）
              onTap: () {
                final read = msg['read'];
                final status = msg['status'];
                if ((read is bool && !read) || (status == 'unread')) {
                  setState(() {
                    _messages[i]['read'] = true;
                    _messages[i]['status'] = 'confirmed'; // 仅用于去除红点的视觉效果
                  });
                  // 重新计算未读数并回调，让外部红点也立即更新
                  final unread = _calcUnread(_messages);
                  widget.onUnreadChanged?.call(unread);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
