import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'dart:convert';
import 'teacher_detail_page.dart';
import '../components/area_selector.dart';

class TeacherListPage extends StatefulWidget {
  /// 进入页面时默认选中的标签：true=线上，false=线下（仅作为默认 Tab，不再是单独页面）
  final bool isOnline;

  /// 头衔过滤 code（0~3），例如 1 = 专业教员，2 = 学霸大学生
  final int? titleFilter;

  const TeacherListPage({
    super.key,
    this.isOnline = false,
    this.titleFilter,
  });

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> teachers = [];
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
      // 切换标签后刷新数据
      _fetchTeachersForCurrentTab();
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
      await _fetchTeachersForCurrentTab();
      await fetchBookings(userId);
    } else {
      await _fetchTeachersForCurrentTab();
    }
  }

  Future<void> _fetchTeachersForCurrentTab() async {
    await fetchTeachers(
      currentProvince,
      currentCity,
      isOnlineTab: _isOnlineTab,
    );
  }

  Future<void> fetchTeachers(String? province, String? city,
      {required bool isOnlineTab}) async {
    try {
      final uri = Uri.parse('$apiBase/api/teachers');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final all = jsonDecode(response.body) as List;
        final allowMethod = isOnlineTab ? '线上' : '线下';

        final filtered = all.where((t) {
          final method = t['teachMethod'] as String? ?? '';
          // 线下需要匹配省市；线上不限制地域
          final regionMatch = isOnlineTab ||
              (province != null &&
                  city != null &&
                  t['province'] == province &&
                  t['city'] == city);

          final matchMethod = method == '全部' || method == allowMethod;

          final code = t['titleCode'];
          final filter = widget.titleFilter;
          // titleCode==3 同时满足 1 和 2
          final matchTitle = filter == null ||
              code == filter ||
              (filter == 1 && code == 3) ||
              (filter == 2 && code == 3);

          return regionMatch && matchMethod && matchTitle;
        }).toList();

        setState(() => teachers = filtered);
      } else {
        throw Exception('获取失败：${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
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

  Future<void> _appointTeacher(Map<String, dynamic> teacher) async {
    if (currentUserId == null || teacher['userId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录或数据缺失')));
      return;
    }

    final appointment = {
      'fromUserId': currentUserId,
      'toUserId': teacher['userId'],
      'targetType': 'teacher',
      'targetId': teacher['_id'],
      'targetInfo': {
        'name': teacher['name'],
        'gender': teacher['gender'],
        'subjects': (teacher['subjects'] as List)
            .map((e) => {'phase': e['phase'], 'subject': e['subject']})
            .toList(),
        'rateMin': teacher['rateMin'],
        'rateMax': teacher['rateMax'],
      },
    };

    try {
      final url = Uri.parse('$apiBase/api/bookings');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(appointment),
      );
      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('预约成功')));
        setState(() => bookedTargetIds.add(teacher['_id']));
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? '预约失败')));
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
        title: Text(widget.titleFilter != null
            ? _titleName(widget.titleFilter!)
            : '老师列表'),
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
                        await fetchTeachers(
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
          if (showAreaSelector &&
              currentProvince != null &&
              currentCity != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                '当前地区：$currentProvince $currentCity',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          Expanded(
            child: teachers.isEmpty
                ? const Center(child: Text('暂无教员信息'))
                : ListView.builder(
                    itemCount: teachers.length,
                    itemBuilder: (context, index) {
                      final t = teachers[index];
                      final isBooked = bookedTargetIds.contains(t['_id']);
                      final subjectList = (t['subjects'] as List)
                          .map((s) => '${s['phase']} ${s['subject']}')
                          .join('，');
                      final accepting =
                          t['acceptingStudents'] as bool? ?? false;
                      final titles = (t['titles'] as List<dynamic>?)
                              ?.cast<String>() ??
                          [];

                      return Stack(
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text('教员：${t['name']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (titles.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6.0),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: titles
                                            .map((tt) => Chip(
                                                  label: Text(
                                                    tt,
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  Text('性别：${t['gender']}'),
                                  Text('身份：${t['identity']}'),
                                  Text('毕业院校：${t['school']}'),
                                  Text('专业：${t['major']}'),
                                  Text('教学经验：${t['exp']}'),
                                  Text(
                                      '报价范围：${t['rateMin']}-${t['rateMax']}'),
                                  Text('授课科目：$subjectList'),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed:
                                    isBooked ? null : () => _appointTeacher(t),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isBooked ? Colors.grey : null,
                                ),
                                child: Text(isBooked ? '已预约' : '预约'),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TeacherDetailPage(teacher: t),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (!accepting)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  '已有学生，暂停接收',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _titleName(int titleCode) {
    switch (titleCode) {
      case 0:
        return '普通教员';
      case 1:
        return '专业教员';
      case 2:
        return '学霸大学生';
      case 3:
        return '专业教员 + 学霸大学生';
      default:
        return '老师列表';
    }
  }
}
