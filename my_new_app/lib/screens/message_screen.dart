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
  // 预约相关
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;

  // 用户上下文
  String? _userId;
  String? _role;

  // 详情页加载遮罩
  bool _loadingDetail = false;

  // 顶部导航的未读数
  int _unreadBookings = 0;
  int _unreadSystem = 0;

  // Tab 控制器
  late final TabController _tabController;

  // SystemMessagesWidget 可刷新用
  final GlobalKey<SystemMessagesWidgetState> _sysMsgKey =
      GlobalKey<SystemMessagesWidgetState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAndFetchAll();
  }

  Future<void> _loadAndFetchAll() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _role = prefs.getString('role');
    if (_userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录，请重新登录')),
      );
      setState(() => _loadingBookings = false);
      return;
    }
    await _fetchBookings();
    // 系统消息自带加载；这里也触发一次刷新以计算未读数
    _sysMsgKey.currentState?.refresh();
  }

  /// 拉取预约消息
  Future<void> _fetchBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final resp =
          await http.get(Uri.parse('$apiBase/api/bookings/to/$_userId'));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is List)
            ? decoded.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _bookings = list;
          _unreadBookings = _calcUnreadBookings(list);
        });
      } else {
        debugPrint('加载预约失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络请求异常: $e');
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  /// 预约未读规则：将 status == 'pending' 视为未读
  int _calcUnreadBookings(List<Map<String, dynamic>> list) {
    int cnt = 0;
    for (final m in list) {
      final status = (m['status'] as String?) ?? '';
      if (status == 'pending') cnt++;
    }
    return cnt;
  }

  /// 确认 or 拒绝预约
  Future<void> _respond(String id, bool accept) async {
    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/api/bookings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': accept ? 'confirmed' : 'rejected'}),
      );
      if (resp.statusCode == 200) {
        // 操作后刷新两类消息
        await _fetchBookings();
        _sysMsgKey.currentState?.refresh();
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

  /// 获取对端（学生/教师）详情（用于跳转详情页）
  Future<Map<String, dynamic>?> _fetchUserDetail(String userId) async {
    final url = (_role == 'teacher')
        ? '$apiBase/api/students?userId=$userId'
        : '$apiBase/api/teachers?userId=$userId';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List &&
            decoded.isNotEmpty &&
            decoded.first is Map<String, dynamic>) {
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              // 这里是本地删除；如果需要同步后端，可在此调用后端删除接口
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

  /// 系统消息未读数回传
  void _onSystemUnreadChanged(int unread) {
    if (!mounted) return;
    setState(() => _unreadSystem = unread);
  }

  /// Tab 标题 + 红点
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
    );
  }

  Widget _buildSystemMessages() {
    // 交给子组件；子组件内部会回传未读数并支持 refresh()
    return SystemMessagesWidget(
      key: _sysMsgKey,
      onUnreadChanged: _onSystemUnreadChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部导航栏
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
