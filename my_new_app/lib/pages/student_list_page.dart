import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'dart:convert';
import 'student_detail_page.dart';
import '../components/area_selector.dart';

class StudentListPage extends StatefulWidget {
  /// 进入页面时默认选中的标签：true=线上，false=线下（仅作为默认 Tab，不再是单独页面）
  final bool isOnline;
  const StudentListPage({super.key, this.isOnline = false});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> students = [];
  String? currentUserId;
  Set<String> bookedTargetIds = {};
  String? currentProvince;
  String? currentCity;

  bool get _isOnlineTab => _tabController.index == 0; // 0=线上，1=线下

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isOnline ? 0 : 1,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _fetchStudentsForCurrentTab();
      setState(() {}); // 触发 AppBar actions 与顶部地区提示的显示切换
    });

    _loadUserIdAndCity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当从后台恢复时，重新读取本地省市并刷新列表
    if (state == AppLifecycleState.resumed) {
      _loadUserIdAndCity();
    }
  }

  Future<void> _loadUserIdAndCity() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final province = prefs.getString('selected_province');
    final city = prefs.getString('selected_city');

    setState(() {
      currentUserId = userId;
      currentProvince = province;
      currentCity = city;
    });

    if (userId != null) {
      await _fetchStudentsForCurrentTab();
      await fetchBookings(userId);
    } else {
      await _fetchStudentsForCurrentTab();
    }
  }

  Future<void> _fetchStudentsForCurrentTab() async {
    await fetchStudents(
      currentProvince,
      currentCity,
      isOnlineTab: _isOnlineTab,
    );
  }

  Future<void> fetchStudents(String? province, String? city,
      {required bool isOnlineTab}) async {
    try {
      final url = Uri.parse('$apiBase/api/students');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final all = jsonDecode(response.body) as List;
        final allowMethod = isOnlineTab ? '线上' : '线下';

        final filtered = all.where((s) {
          final method = s['teachMethod'] as String? ?? '';
          final isPublic = s['isPublic'] as bool? ?? false;

          // 线下需要匹配省市；线上不限制地域
          final regionMatch = isOnlineTab ||
              (province != null &&
                  city != null &&
                  s['province'] == province &&
                  s['city'] == city);

          final matchMethod = method == '全部' || method == allowMethod;

          return isPublic && regionMatch && matchMethod;
        }).toList();

        setState(() {
          students = filtered;
        });
      } else {
        throw Exception('获取失败：${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载失败: $e')));
    }
  }

  Future<void> fetchBookings(String userId) async {
    try {
      final url = Uri.parse('$apiBase/api/bookings/from/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          bookedTargetIds =
              data.map((b) => b['targetId'].toString()).toSet();
        });
      } else {
        throw Exception('加载预约记录失败：${response.statusCode}');
      }
    } catch (e) {
      debugPrint('加载预约记录异常: $e');
    }
  }

  Future<void> _sendAppointment(Map<String, dynamic> student) async {
    if (currentUserId == null || student['userId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前用户或目标用户信息缺失')));
      return;
    }
    final appointment = {
      'fromUserId': currentUserId,
      'toUserId': student['userId'],
      'targetType': 'student',
      'targetId': student['_id'],
      'targetInfo': {
        'name': student['name'],
        'gender': student['gender'],
        'subjects': (student['subjects'] as List)
            .map((e) => {
                  'phase': e['phase'],
                  'subject': e['subject'],
                })
            .toList(),
        'rateMin': student['rateMin'],
        'rateMax': student['rateMax'],
      },
    };
    try {
      final url = Uri.parse('$apiBase/api/bookings');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(appointment),
      );
      if (resp.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('预约成功')));
        setState(() => bookedTargetIds.add(student['_id']));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('预约失败: ${resp.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAreaSelector = !_isOnlineTab;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学生需求列表'),
        actions: showAreaSelector
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: AreaSelector(
                      onSelected: (province, city) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('selected_province', province);
                        await prefs.setString('selected_city', city);
                        setState(() {
                          currentProvince = province;
                          currentCity = city;
                        });
                        await fetchStudents(
                          province,
                          city,
                          isOnlineTab: _isOnlineTab,
                        );
                      },
                    ),
                  ),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '线上'),
            Tab(text: '线下'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('暂无学生信息'))
                : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      final isBooked = bookedTargetIds.contains(s['_id']);
                      final subjectList = (s['subjects'] as List)
                          .map((e) => '${e['phase']} ${e['subject']}')
                          .join('，');
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('学生：${s['name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('性别：${s['gender']}'),
                              Text('对教员性别要求：${s['tutorGender']}'),
                              Text('对教员身份要求：${s['tutorIdentity']}'),
                              Text('报价范围：${s['rateMin']}-${s['rateMax']}'),
                              Text('上课时长：${s['duration']}小时'),
                              Text('一周次数：${s['frequency']}次'),
                              Text('上课地点：${s['region']}'),
                              Text('学习科目：$subjectList'),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed:
                                isBooked ? null : () => _sendAppointment(s),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBooked ? Colors.grey : null,
                            ),
                            child: Text(isBooked ? '已预约' : '预约'),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailPage(student: s),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
