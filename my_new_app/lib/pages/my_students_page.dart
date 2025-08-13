import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import 'student_detail_page.dart';

class MyStudentsPage extends StatefulWidget {
  const MyStudentsPage({Key? key}) : super(key: key);

  @override
  _MyStudentsPageState createState() => _MyStudentsPageState();
}

class _MyStudentsPageState extends State<MyStudentsPage> {
  bool _loading = true;
  String? _userId;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      if (_userId == null) throw '未登录';

      // 1) 从确认预约库拿“与我相关（任意角色）”的预约
      //    注意：路径要用带中横线的 confirmed-bookings
      final confirmedResp = await http.get(
        Uri.parse('$apiBase/api/confirmed-bookings/$_userId'),
      );
      if (confirmedResp.statusCode != 200) {
        throw '获取预约失败 (${confirmedResp.statusCode})';
      }
      final decoded = jsonDecode(confirmedResp.body);
      final List bookings = (decoded is List) ? decoded : const [];

      // 2) 仅取“我是教师”的预约，拿对端 student.userId，再去查学生详情
      final seen = <String>{};
      final result = <Map<String, dynamic>>[];

      for (final item in bookings) {
        final m = (item is Map) ? item : {};
        final teacher = (m['teacher'] ?? {}) as Map;
        final teacherId = (teacher['userId'] ?? '') as String;
        if (teacherId != _userId) continue;

        final student = (m['student'] ?? {}) as Map;
        final studentId = (student['userId'] ?? '') as String;
        if (studentId.isEmpty || seen.contains(studentId)) continue;

        final detail = await _fetchStudentDetail(studentId);
        if (detail != null) {
          result.add(detail);
          seen.add(studentId);
        }
      }

      if (!mounted) return;
      setState(() => _students = result);
    } catch (e) {
      debugPrint('加载学生失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载学生失败：$e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 兼容两种返回形式：
  /// - [ {...} ]（/api/students?userId=）
  /// - { data: [ {...} ] }（若将来后端统一分页格式）
  Future<Map<String, dynamic>?> _fetchStudentDetail(String studentUserId) async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/students?userId=$studentUserId'),
      );
      if (resp.statusCode != 200) return null;
      final d = jsonDecode(resp.body);

      if (d is List && d.isNotEmpty && d.first is Map) {
        return Map<String, dynamic>.from(d.first as Map);
      }
      if (d is Map && d['data'] is List && (d['data'] as List).isNotEmpty) {
        final first = (d['data'] as List).first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
    } catch (e) {
      debugPrint('拉取学生详情失败: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的学生')),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text('暂无已确认的学生'))
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final stu = _students[index];

                      final List subjects = (stu['subjects'] is List)
                          ? (stu['subjects'] as List)
                          : const [];
                      final subjectText = subjects
                          .map((e) {
                            final m = (e is Map) ? e : {};
                            final phase = (m['phase'] ?? '').toString();
                            final subject = (m['subject'] ?? '').toString();
                            return '$phase$subject';
                          })
                          .where((s) => s.trim().isNotEmpty)
                          .join('，');

                      final displayName = (stu['name'] ??
                              stu['realName'] ??
                              stu['studentName'] ??
                              '')
                          .toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          title:
                              Text(displayName.isEmpty ? '学生' : displayName),
                          subtitle: subjectText.isEmpty
                              ? null
                              : Text('科目：$subjectText'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailPage(student: stu),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
