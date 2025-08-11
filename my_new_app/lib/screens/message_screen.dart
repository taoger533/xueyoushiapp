import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import '../components/system_messages_widget.dart';
import '../pages/student_detail_page.dart';
import '../pages/teacher_detail_page.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({Key? key}) : super(key: key);

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  List<Map<String, dynamic>> _bookings = [];
  String? _userId;
  String? _role;
  bool _loadingBookings = true;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadAndFetchBookings();
  }

  Future<void> _loadAndFetchBookings() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _role = prefs.getString('role');
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录，请重新登录')),
      );
      setState(() => _loadingBookings = false);
      return;
    }
    await _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final resp = await http.get(Uri.parse('$apiBase/api/bookings/to/$_userId'));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is List)
            ? decoded.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        setState(() => _bookings = list);
      } else {
        debugPrint('加载预约失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络请求异常: $e');
    } finally {
      setState(() => _loadingBookings = false);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/api/bookings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': accept ? 'confirmed' : 'rejected'}),
      );
      if (resp.statusCode == 200) {
        await _fetchBookings();
      } else {
        throw Exception('服务器返回 ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('处理预约失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDetail(String userId) async {
    final url = (_role == 'teacher')
        ? '$apiBase/api/students?userId=$userId'
        : '$apiBase/api/teachers?userId=$userId';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
          return decoded.first as Map<String, dynamic>;
        }
      } else {
        debugPrint('获取详情接口异常: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('获取用户详情失败: $e');
    }
    return null;
  }

  Future<void> _openDetail(String userId) async {
    setState(() => _loadingDetail = true);
    final detail = await _fetchUserDetail(userId);
    setState(() => _loadingDetail = false);
    if (detail != null) {
      if (_role == 'teacher') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentDetailPage(student: detail)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeacherDetailPage(teacher: detail)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载详细信息失败')),
      );
    }
  }

  void _deleteBooking(String id, int idx) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除预约消息'),
        content: const Text('确定要删除这条预约消息？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              setState(() => _bookings.removeAt(idx));
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              if (_loadingBookings)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_bookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('暂无预约消息')),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bookings.length,
                  itemBuilder: (context, i) {
                    final msg = _bookings[i];
                    final sender = msg['fromUserId'] as Map<String, dynamic>?;
                    final senderId = (sender?['_id'] as String?) ?? '';
                    final status = msg['status'] as String? ?? '';
                    final info = msg['targetInfo'] as Map<String, dynamic>?;

                    return GestureDetector(
                      onTap: senderId.isNotEmpty ? () => _openDetail(senderId) : null,
                      onLongPress: () => _deleteBooking(msg['_id'].toString(), i),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('来自 ${info?['name'] ?? ''} 的预约'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (info != null) ...[
                                Text('性别：${info['gender'] ?? ''}'),
                                Text(
                                  '科目：${(info['subjects'] as List?)
                                      ?.map((e) => '${e['phase']} ${e['subject']}')
                                      .join('，') ?? ''}',
                                ),
                                Text('报价：${info['rateMin'] ?? ''} - ${info['rateMax'] ?? ''}'),
                              ],
                              Text(
                                '状态：$status',
                                style: TextStyle(
                                  color: status == 'confirmed'
                                      ? Colors.green
                                      : status == 'rejected'
                                          ? Colors.red
                                          : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (status == 'pending')
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _respond(msg['_id'].toString(), true),
                                      child: const Text('确认'),
                                    ),
                                    TextButton(
                                      onPressed: () => _respond(msg['_id'].toString(), false),
                                      child: const Text('拒绝'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),
              const SystemMessagesWidget(),
            ],
          ),
        ),
        if (_loadingDetail) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
