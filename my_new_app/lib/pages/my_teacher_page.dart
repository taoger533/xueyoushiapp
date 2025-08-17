import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config.dart';
import 'teacher_detail_page.dart';

class MyTeachersPage extends StatefulWidget {
  const MyTeachersPage({Key? key}) : super(key: key);

  @override
  _MyTeachersPageState createState() => _MyTeachersPageState();
}

class _MyTeachersPageState extends State<MyTeachersPage> {
  bool _loading = true;
  String? _userId;
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      if (_userId == null) throw '未登录';

      // 1) 从确认预约库拿与我相关的预约（注意：带中横线的路径）
      final confirmedResp = await http.get(
        Uri.parse('$apiBase/api/confirmed-bookings/$_userId'),
      );
      if (confirmedResp.statusCode != 200) {
        throw '获取预约失败 (${confirmedResp.statusCode})';
      }
      final decoded = jsonDecode(confirmedResp.body);
      final List bookings = (decoded is List) ? decoded : const [];

      // 2) 仅取“我是学生”的预约，收集 teacher.userId（去重）
      final seen = <String>{};
      final teacherIds = <String>[];

      for (final item in bookings) {
        final m = (item is Map) ? item : {};
        final student = (m['student'] ?? {}) as Map;
        final studentId = (student['userId'] ?? '') as String;
        if (studentId != _userId) continue;

        final teacher = (m['teacher'] ?? {}) as Map;
        final teacherId = (teacher['userId'] ?? '') as String;
        if (teacherId.isEmpty || seen.contains(teacherId)) continue;

        seen.add(teacherId);
        teacherIds.add(teacherId);
      }

      // 3) 并发拉取老师详情
      final futures = teacherIds.map(_fetchTeacherDetail);
      final details = await Future.wait(futures);

      final result = <Map<String, dynamic>>[];
      for (final d in details) {
        if (d != null) result.add(d);
      }

      if (!mounted) return;
      setState(() => _teachers = result);
    } catch (e) {
      debugPrint('加载教师失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载老师失败：$e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 兼容两种返回形式：
  /// - [ {...} ]（/api/teachers?userId=）
  /// - { data: [ {...} ] }（若将来后端统一成分页结构）
  Future<Map<String, dynamic>?> _fetchTeacherDetail(String teacherUserId) async {
    try {
      final resp =
          await http.get(Uri.parse('$apiBase/api/teachers?userId=$teacherUserId'));
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
      debugPrint('拉取老师详情失败: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待试课老师')),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _teachers.isEmpty
              ? const Center(child: Text('暂无待试课的老师'))
              : RefreshIndicator(
                  onRefresh: _loadTeachers,
                  child: ListView.builder(
                    itemCount: _teachers.length,
                    itemBuilder: (context, index) {
                      final tea = _teachers[index];

                      // 名称兜底
                      final displayName = (tea['name'] ??
                              tea['realName'] ??
                              tea['teacherName'] ??
                              '')
                          .toString();

                      // 科目兜底
                      final List subjects = (tea['subjects'] is List)
                          ? (tea['subjects'] as List)
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

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(displayName.isEmpty ? '老师' : displayName),
                          subtitle: subjectText.isEmpty ? null : Text('科目：$subjectText'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeacherDetailPage(teacher: tea),
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
