import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'dart:convert';
import 'student_detail_page.dart';
import '../components/area_selector.dart';
import '../components/teacher_filter_bar.dart';

/// 学生需求列表页。
///
/// 与教员列表类似，通过 TabBar 区分线上/线下学生需求，并添加学段、科目、性别筛选。
class StudentListPage extends StatefulWidget {
  /// 进入页面时默认选中的标签：true=线上，false=线下
  final bool isOnline;

  const StudentListPage({super.key, this.isOnline = false});

  @override
  State createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 学生列表数据
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

  // 当前选中的 Tab 是否为线上模式（0=线上，1=线下）
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
      _fetchStudentsForCurrentTab();
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

  /// 根据当前 Tab 和筛选条件获取学生列表。
  Future<void> fetchStudents(String? province, String? city,
      {required bool isOnlineTab}) async {
    try {
      final queryParameters = <String, String>{};
      final method = isOnlineTab ? '线上' : '线下';
      queryParameters['teachMethod'] = method;
      if (!isOnlineTab) {
        if (province != null) queryParameters['province'] = province;
        if (city != null) queryParameters['city'] = city;
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
      final uri = Uri.parse('$apiBase/api/students')
          .replace(queryParameters: queryParameters);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final casted = data
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() => students = casted);
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

  /// 获取当前用户的预约记录。
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
    } catch (e) {
      debugPrint('加载预约记录异常: $e');
    }
  }

  /// 向学生发送预约。
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
          // 筛选栏：学段、科目、性别
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
              _fetchStudentsForCurrentTab();
            },
            onSubjectChanged: (value) {
              setState(() {
                selectedSubject = value ?? '全部';
              });
              _fetchStudentsForCurrentTab();
            },
            onGenderChanged: (value) {
              setState(() {
                selectedGender = value ?? '全部';
              });
              _fetchStudentsForCurrentTab();
            },
          ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('暂无学生信息'))
                : ListView.builder(
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
                            onPressed: isBooked
                                ? null
                                : () => _sendAppointment(student),
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
                                    StudentDetailPage(student: student),
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
