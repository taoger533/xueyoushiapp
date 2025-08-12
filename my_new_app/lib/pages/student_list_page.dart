import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'dart:convert';
import 'student_detail_page.dart';
import '../components/area_selector.dart';
import '../components/teacher_filter_bar.dart';
import '../components/refresh_paged_list.dart';

/// 学生需求列表页：分页 + 下拉刷新 + 触底加载 + 学段/科目/性别筛选
class StudentListPage extends StatefulWidget {
  final bool isOnline; // 进入页面默认tab：true=线上，false=线下
  const StudentListPage({super.key, this.isOnline = false});

  @override
  State createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 列表数据
  List<Map<String, dynamic>> students = [];
  String? currentUserId;
  Set<String> bookedTargetIds = {};
  String? currentProvince;
  String? currentCity;

  // 筛选条件
  String? selectedPhase = '全部';
  String? selectedSubject = '全部';
  String? selectedGender = '全部';
  final List<String> phaseOptions = ['全部', '小学', '初中', '高中'];
  final List<String> subjectOptions = [
    '全部', '语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理'
  ];
  final List<String> genderOptions = ['全部', '男', '女'];

  // 分页
  int _page = 1;
  final int _limit = 20;
  int _total = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  bool get _isOnlineTab => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.isOnline ? 0 : 1,
    )..addListener(() {
        if (_tabController.indexIsChanging) return;
        _resetAndFetch(); // 切换线上/线下时重置并拉取
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
    await _resetAndFetch();
    if (userId != null) {
      await fetchBookings(userId);
    }
  }

  Future<void> _resetAndFetch() async {
    setState(() {
      _page = 1;
      _total = 0;
      _hasMore = true;
      students = [];
    });
    await _fetchStudents();
  }

  /// 拉取学生列表（与后端分页结构对齐）
  Future<void> _fetchStudents({bool nextPage = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final queryParameters = <String, String>{};
      final method = _isOnlineTab ? '线上' : '线下';
      queryParameters['teachMethod'] = method;

      if (!_isOnlineTab) {
        if (currentProvince != null) queryParameters['province'] = currentProvince!;
        if (currentCity != null) queryParameters['city'] = currentCity!;
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

      final pageToLoad = nextPage ? (_page + 1) : _page;
      queryParameters['page'] = pageToLoad.toString();
      queryParameters['limit'] = _limit.toString();

      final uri =
          Uri.parse('$apiBase/api/students').replace(queryParameters: queryParameters);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final obj = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> dataList = obj['data'] ?? [];
        final int total = (obj['total'] ?? 0) as int;

        final newItems = dataList
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          _total = total;
          _page = pageToLoad;
          students = [...students, ...newItems];
          _hasMore = students.length < _total;
        });
      } else {
        throw Exception('获取失败：${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 预约
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
            .map((e) => {'phase': e['phase'], 'subject': e['subject']})
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
        setState(() => bookedTargetIds.add(student['_id'].toString()));
      } else {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['error'] ?? '预约失败')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  /// 当前用户的预约记录（用于置灰“已预约”）
  Future<void> fetchBookings(String userId) async {
    try {
      final url = Uri.parse('$apiBase/api/bookings/from/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          bookedTargetIds =
              data.map((b) => b['targetId'].toString()).toSet();
        });
      } else {
        throw Exception('加载预约记录失败：${response.statusCode}');
      }
    } catch (_) {}
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
                        await _resetAndFetch();
                      },
                    ),
                  ),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '线上'), Tab(text: '线下')],
        ),
      ),
      body: Column(
        children: [
          // 学段/科目/性别 筛选
          TeacherFilterBar(
            phases: phaseOptions,
            subjects: subjectOptions,
            genders: genderOptions,
            selectedPhase: selectedPhase,
            selectedSubject: selectedSubject,
            selectedGender: selectedGender,
            onPhaseChanged: (value) async {
              setState(() => selectedPhase = value ?? '全部');
              await _resetAndFetch();
            },
            onSubjectChanged: (value) async {
              setState(() => selectedSubject = value ?? '全部');
              await _resetAndFetch();
            },
            onGenderChanged: (value) async {
              setState(() => selectedGender = value ?? '全部');
              await _resetAndFetch();
            },
          ),
          Expanded(
            child: RefreshPagedList(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final isBooked =
                    bookedTargetIds.contains(student['_id'].toString());
                final subjectList = (student['subjects'] as List)
                    .map((e) => '${e['phase']} ${e['subject']}')
                    .join('，');
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('学生：${student['name']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('性别：${student['gender']}'),
                        Text('对教员性别要求：${student['tutorGender']}'),
                        Text('对教员身份要求：${student['tutorIdentity']}'),
                        Text('报价范围：${student['rateMin']}-${student['rateMax']}'),
                        Text('上课时长：${student['duration']}小时'),
                        Text('一周次数：${student['frequency']}次'),
                        Text('上课地点：${student['region']}'),
                        Text('学习科目：$subjectList'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: isBooked ? null : () => _sendAppointment(student),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBooked ? Colors.grey : null,
                      ),
                      child: Text(isBooked ? '已预约' : '预约'),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailPage(student: student),
                        ),
                      );
                    },
                  ),
                );
              },
              onRefresh: _resetAndFetch,
              onLoadMore: () => _fetchStudents(nextPage: true),
              isLoading: _isLoading,
              hasMore: _hasMore,
              empty: const Text('暂无学生信息'),
              padding: const EdgeInsets.only(bottom: 8),
            ),
          ),
        ],
      ),
    );
  }
}
