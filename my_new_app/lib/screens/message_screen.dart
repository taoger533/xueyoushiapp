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

class _MessageScreenState extends State<MessageScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;

  String? _userId;
  String? _role;

  bool _loadingDetail = false;

  int _unreadBookings = 0;
  int _unreadSystem = 0;

  late final TabController _tabController;

  final GlobalKey<SystemMessagesWidgetState> _sysMsgKey =
      GlobalKey<SystemMessagesWidgetState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAndFetchAll();
  }

  // ================= 宽容工具函数 =================

  /// 既接受 Map，也接受 JSON 字符串；其他类型返回 null
  Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return v.map((k, value) => MapEntry(k.toString(), value));
    }
    if (v is String && v.trim().isNotEmpty) {
      try {
        final d = jsonDecode(v);
        if (d is Map) {
          return d.map((k, value) => MapEntry(k.toString(), value));
        }
      } catch (e) {
        debugPrint('[_asMap] jsonDecode 失败: $e, 原值=$v');
      }
    }
    return null;
  }

  /// 兼容 fromUserId 既可能是字符串、也可能是 { _id: '...' }
  String _asId(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map && v['_id'] is String) return v['_id'] as String;
    return v.toString();
  }

  /// 调试：安全拿科目文本，并打印关键信息
  String _subjectTextFrom(dynamic subjectsRaw) {
    debugPrint('[subjects] runtimeType=${subjectsRaw.runtimeType} value=$subjectsRaw');
    final List<dynamic> subjects =
        (subjectsRaw is List) ? List<dynamic>.from(subjectsRaw) : const <dynamic>[];
    final List<String> parts = <String>[];
    for (final e in subjects) {
      if (e is Map) {
        final phase = (e['phase'] ?? '').toString();
        final subject = (e['subject'] ?? '').toString();
        final seg = [phase, subject].where((s) => s.isNotEmpty).join(' ');
        if (seg.isNotEmpty) parts.add(seg);
      } else {
        debugPrint('[subjects] 非 Map 项: type=${e.runtimeType}, value=$e');
      }
    }
    return parts.join('，');
  }

  // ================= 数据加载 =================

  Future<void> _loadAndFetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _role = prefs.getString('role');
    debugPrint('[init] userId=$_userId role=$_role');

    if (_userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录，请重新登录')),
      );
      setState(() => _loadingBookings = false);
      return;
    }
    await _fetchBookings();
    _sysMsgKey.currentState?.refresh();
  }

  Future<void> _fetchBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final url = '$apiBase/api/bookings/to/$_userId';
      debugPrint('[fetchBookings] GET $url');
      final resp = await http.get(Uri.parse(url));
      debugPrint('[fetchBookings] status=${resp.statusCode} bodyLen=${resp.body.length}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is List)
            ? decoded
                .map((e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{'__raw__': e})
                .whereType<Map<String, dynamic>>()
                .toList()
            : <Map<String, dynamic>>[];

        for (int i = 0; i < list.length && i < 3; i++) {
          debugPrint('[fetchBookings] sample[$i]=${jsonEncode(list[i])}');
        }

        setState(() {
          _bookings = list;
          _unreadBookings = _calcUnreadBookings(list);
        });
      } else {
        debugPrint('加载预约失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e, st) {
      debugPrint('网络请求异常: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  int _calcUnreadBookings(List<Map<String, dynamic>> list) {
    int cnt = 0;
    for (final m in list) {
      final status = (m['status'] as String?) ?? '';
      if (status == 'pending') cnt++;
    }
    return cnt;
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      final url = '$apiBase/api/bookings/$id';
      debugPrint('[respond] PATCH $url accept=$accept');
      final resp = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': accept ? 'confirmed' : 'rejected'}),
      );
      debugPrint('[respond] status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200) {
        await _fetchBookings();
        _sysMsgKey.currentState?.refresh();
      } else {
        throw Exception('服务器返回 ${resp.statusCode}');
      }
    } catch (e, st) {
      debugPrint('处理预约失败: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理失败: $e')),
        );
      }
    }
  }

  /// 关键修复：按“发起者角色”选择接口，而不是用当前用户角色
  Future<Map<String, dynamic>?> _fetchUserDetail(String userId, String senderRole) async {
    final bool isStudent = senderRole == 'student';
    final url = isStudent
        ? '$apiBase/api/students/user/$userId'
        : '$apiBase/api/teachers/user/$userId';
    debugPrint('[fetchDetail] senderRole=$senderRole url=$url');

    try {
      final resp = await http.get(Uri.parse(url));
      debugPrint('[fetchDetail] status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return (decoded.first as Map).cast<String, dynamic>();
        } else if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } else {
        debugPrint('获取详情接口异常: ${resp.statusCode} ');
      }
    } catch (e, st) {
      debugPrint('获取用户详情失败: $e\n$st');
    }
    return null;
  }

  /// 关键修复：按“发起者角色”选择进入哪个详情页，而不是用当前用户角色
  Future<void> _openDetail(String userId, String senderRole) async {
    debugPrint('[openDetail] tap userId=$userId senderRole=$senderRole (currentRole=$_role)');
    setState(() => _loadingDetail = true);
    final detail = await _fetchUserDetail(userId, senderRole);
    setState(() => _loadingDetail = false);

    final bool isStudent = senderRole == 'student';
    if (detail != null) {
      debugPrint('[openDetail] got detail keys=${detail.keys.toList()}');
      if (isStudent) {
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
      debugPrint('[openDetail] detail=null, 兜底仅传 userId 进入详情页');
      if (isStudent) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDetailPage(student: {'userId': userId}),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherDetailPage(teacher: {'userId': userId}),
          ),
        );
      }
    }
  }

  void _deleteBooking(String id, int idx) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除预约消息'),
        content: const Text('确定要删除这条预约消息？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              setState(() => _bookings.removeAt(idx));
              setState(() => _unreadBookings = _calcUnreadBookings(_bookings));
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _onSystemUnreadChanged(int unread) {
    if (!mounted) return;
    setState(() => _unreadSystem = unread);
  }

  Widget _tabLabel(String text, int unread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(text),
        ),
        if (unread > 0)
          Positioned(
            right: -14,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBookingsList() {
    if (_loadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bookings.isEmpty) {
      return const Center(child: Text('暂无预约消息'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchBookings();
        _sysMsgKey.currentState?.refresh();
      },
      child: ListView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, i) {
          try {
            final msg = _bookings[i];

            debugPrint('--- [item $i] ---');
            debugPrint('[item $i] raw=${jsonEncode(msg)}');

            final String senderId = _asId(msg['fromUserId']);
            final String targetType = (msg['targetType'] as String?) ?? '';
            // 收到消息中：发起者角色 = targetType 对立面
            final String senderRole =
                targetType == 'teacher' ? 'student' : 'teacher';

            final Map<String, dynamic>? initiator = _asMap(msg['initiatorInfo']);
            final Map<String, dynamic>? targetInfo = _asMap(msg['targetInfo']);
            final Map<String, dynamic>? displayInfo = initiator ?? targetInfo;

            debugPrint('[item $i] senderId=$senderId targetType=$targetType senderRole=$senderRole');
            debugPrint('[item $i] initiator.keys=${initiator?.keys.toList()} targetInfo.keys=${targetInfo?.keys.toList()}');

            final String subjectText = _subjectTextFrom(displayInfo?['subjects']);
            final String status = (msg['status'] as String?) ?? '';

            return GestureDetector(
              onTap: senderId.isNotEmpty ? () => _openDetail(senderId, senderRole) : null,
              onLongPress: () => _deleteBooking(msg['_id'].toString(), i),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text("来自 ${displayInfo?['name'] ?? ''} 的预约"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayInfo != null) ...[
                        Text("性别：${displayInfo['gender'] ?? ''}"),
                        Text("科目：$subjectText"),
                        Text(
                            "报价：${displayInfo['rateMin'] ?? ''} - ${displayInfo['rateMax'] ?? ''}"),
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
                              onPressed: () =>
                                  _respond(msg['_id'].toString(), true),
                              child: const Text('确认'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _respond(msg['_id'].toString(), false),
                              child: const Text('拒绝'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          } catch (e, st) {
            debugPrint('[item builder] 解析异常: $e\n$st');
            final raw = (_bookings[i]).toString();
            return Card(
              color: Colors.amber.shade50,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: const Text('这条预约数据解析失败（已记录日志）'),
                subtitle: Text(
                  raw.length > 400 ? '${raw.substring(0, 400)}...' : raw,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSystemMessages() {
    return SystemMessagesWidget(
      key: _sysMsgKey,
      onUnreadChanged: _onSystemUnreadChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              _tabLabel('预约消息', _unreadBookings),
              _tabLabel('系统消息', _unreadSystem),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingsList(),
                  _buildSystemMessages(),
                ],
              ),
              if (_loadingDetail)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }
}
