import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'dart:convert';
import 'teacher_detail_page.dart';
import '../components/teacher_card.dart';
import '../components/teacher_filter_bar.dart';
import '../components/area_selector.dart';

class TeacherListPage extends StatefulWidget {
  final bool isOnline;
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
  List<Map<String, dynamic>> teachers = [];
  String? currentUserId;
  Set<String> bookedTargetIds = {};
  String? currentProvince;
  String? currentCity;

  String? selectedPhase = '全部';
  String? selectedSubject = '全部';
  String? selectedGender = '全部';

  final List<String> phaseOptions = ['全部', '小学', '初中', '高中'];
  final List<String> subjectOptions = [
    '全部',
    '语文',
    '数学',
    '英语',
    '物理',
    '化学',
    '生物',
    '历史',
    '地理'
  ];
  final List<String> genderOptions = ['全部', '男', '女'];

  bool get _isOnlineTab => _tabController.index == 0;

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
      _fetchTeachersForCurrentTab();
      setState(() {});
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
      final queryParameters = <String, String>{};
      final method = isOnlineTab ? '线上' : '线下';
      queryParameters['teachMethod'] = method;
      if (!isOnlineTab) {
        if (province != null) queryParameters['province'] = province;
        if (city != null) queryParameters['city'] = city;
      }
      if (widget.titleFilter != null) {
        queryParameters['titleFilter'] = widget.titleFilter.toString();
      }
      if (selectedPhase != null) {
        queryParameters['phase'] = selectedPhase!;
      }
      if (selectedSubject != null) {
        queryParameters['subject'] = selectedSubject!;
      }
      if (selectedGender != null) {
        queryParameters['gender'] = selectedGender!;
      }
      final uri = Uri.parse('$apiBase/api/teachers')
          .replace(queryParameters: queryParameters);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final casted = data
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() => teachers = casted);
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
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          bookedTargetIds = data.map((b) => b['targetId'].toString()).toSet();
        });
      } else {
        throw Exception('加载预约记录失败：${response.statusCode}');
      }
    } catch (_) {}
  }

  Future<void> _appointTeacher(Map<String, dynamic> teacher) async {
    if (currentUserId == null || teacher['userId'] == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录或数据缺失')));
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
        setState(() => bookedTargetIds.add(teacher['_id'].toString()));
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? '预约失败')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('网络错误')));
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
          TeacherFilterBar(
            phases: phaseOptions,
            subjects: subjectOptions,
            genders: genderOptions,
            selectedPhase: selectedPhase,
            selectedSubject: selectedSubject,
            selectedGender: selectedGender,
            onPhaseChanged: (value) {
              setState(() {
                selectedPhase = value ?? '全部';
              });
              _fetchTeachersForCurrentTab();
            },
            onSubjectChanged: (value) {
              setState(() {
                selectedSubject = value ?? '全部';
              });
              _fetchTeachersForCurrentTab();
            },
            onGenderChanged: (value) {
              setState(() {
                selectedGender = value ?? '全部';
              });
              _fetchTeachersForCurrentTab();
            },
          ),
          Expanded(
            child: teachers.isEmpty
                ? const Center(child: Text('暂无教员信息'))
                : ListView.builder(
                    itemCount: teachers.length,
                    itemBuilder: (context, index) {
                      final t = teachers[index];
                      final isBooked =
                          bookedTargetIds.contains(t['_id'].toString());
                      return TeacherCard(
                        teacher: t,
                        isBooked: isBooked,
                        onBook: () => _appointTeacher(t),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherDetailPage(teacher: t),
                            ),
                          );
                        },
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
