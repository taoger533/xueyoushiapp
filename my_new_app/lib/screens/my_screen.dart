import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import '../pages/my_students_page.dart';
import '../pages/my_teacher_page.dart';
import '../pages/pending_reviews_page.dart';
import '../pages/payment_page.dart';
import '../pages/professional_certification_page.dart';
import '../pages/top_student_certification_page.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  String _role = '';
  bool _isMember = false;
  double _rating = 0.0;
  int _studentsCount = 0;
  List<String> _titles = [];
  bool _acceptingStudents = false;
  bool _professionalCertified = false;
  bool _topStudentCertified = false;

  /// 本地头衔映射
  final Map<int, List<String>> titleCodeMap = {
    0: ['普通教员'],
    1: ['专业教员'],
    2: ['学霸大学生'],
    3: ['专业教员', '学霸大学生'],
  };

  @override
  void initState() {
    super.initState();
    _loadRoleAndStatus();
  }

  Future<void> _loadRoleAndStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final role = prefs.getString('user_role') ?? '';

    if (userId == null) return;

    try {
      final resp = await http.get(Uri.parse('$apiBase/api/user-info/$userId'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final titleCode = data['titleCode'] ?? 0;

        setState(() {
          _role = role;
          _isMember = data['isMember'] ?? false;
          _rating = (data['rating'] ?? 0).toDouble();
          _studentsCount = data['studentsCount'] ?? 0;
          _titles = titleCodeMap[titleCode] ?? ['普通教员'];
          _acceptingStudents = data['acceptingStudents'] ?? false;
          _professionalCertified = data['professionalCertified'] ?? false;
          _topStudentCertified = data['topStudentCertified'] ?? false;
        });
      }
    } catch (e) {
      print('获取用户信息异常: $e');
    }
  }

  Future<void> _toggleField(String field, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;
    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/api/user-info/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({field: val}),
      );
      if (resp.statusCode == 200) {
        setState(() {
          switch (field) {
            case 'acceptingStudents':
              _acceptingStudents = val;
              break;
            case 'isMember':
              _isMember = val;
              break;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新 $field 失败')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新 $field 异常')),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.card_membership),
              title: const Text('会员状态'),
              subtitle: Text(_isMember ? '已开通' : '未开通'),
              trailing: TextButton(
                onPressed: _isMember
                    ? null
                    : () async {
                        final scenarioId =
                            _role == 'teacher' ? 'member_teacher' : 'member_student';
                        final success = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PaymentPage(scenarioId: scenarioId)),
                        );
                        if (success == true) _toggleField('isMember', true);
                      },
                child: Text(_isMember ? '已开通' : '去开通'),
              ),
            ),
            const Divider(),
            if (_role == 'teacher') ...[
              if (_titles.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: const Text('教员头衔'),
                  subtitle: Text(_titles.join(', ')),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.how_to_reg),
                title: const Text('接收学生状态'),
                value: _acceptingStudents,
                onChanged: (v) => _toggleField('acceptingStudents', v),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('专业教员认证'),
                trailing: TextButton(
                  onPressed: _professionalCertified
                      ? null
                      : () async {
                          final success = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfessionalCertificationPage()),
                          );
                          if (success == true) _loadRoleAndStatus();
                        },
                  child: const Text('去认证'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('学霸大学生认证'),
                trailing: TextButton(
                  onPressed: _topStudentCertified
                      ? null
                      : () async {
                          final success = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TopStudentCertificationPage()),
                          );
                          if (success == true) _loadRoleAndStatus();
                        },
                  child: const Text('去认证'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: const Text('评分'),
                trailing: Text(_rating.toStringAsFixed(1)),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('教过的学生总数'),
                trailing: Text('$_studentsCount'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('待试课学生'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyStudentsPage()),
                  );
                },
              ),
            ] else if (_role == 'student') ...[
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('待试课老师'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTeachersPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.rate_review),
                title: const Text('待评价'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingReviewsScreen()),
                  );
                },
              ),
            ],
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('确认退出'),
                      content: const Text('确定要退出登录吗？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                      ],
                    ),
                  );
                  if (confirm == true) await _logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
