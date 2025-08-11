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

      // 1. 获取所有与我相关的已确认预约（既包括我是学生，也包括我是教师）
      final confirmedResp = await http.get(
        Uri.parse('$apiBase/api/confirmed-bookings/$_userId'),
      );
      if (confirmedResp.statusCode != 200) throw '获取预约失败';
      final confirmedList = jsonDecode(confirmedResp.body) as List;

      // 2. 遍历每一条，只处理我是“教师”角色的记录，从 booking.student.userId 查询学生详情
      final List<Map<String, dynamic>> students = [];
      for (var item in confirmedList) {
        // item 格式：{ student: { userId, name, subjects }, teacher: { ... } }
        if (item['teacher']['userId'] == _userId) {
          final String studentId = item['student']['userId'];
          final detailResp = await http.get(
            Uri.parse('$apiBase/api/students?userId=$studentId'),
          );
          if (detailResp.statusCode == 200) {
            final data = jsonDecode(detailResp.body);
            if (data is List && data.isNotEmpty) {
              students.add(Map<String, dynamic>.from(data.first));
            }
          }
        }
      }

      setState(() => _students = students);
    } catch (e) {
      debugPrint('加载学生失败: $e');
    } finally {
      setState(() => _loading = false);
    }
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
              : ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final stu = _students[index];
                    final subjectText = (stu['subjects'] as List)
                        .map((e) => '${e['phase']}${e['subject']}')
                        .join('，');
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(stu['name'] ?? ''),
                        subtitle: Text('科目：$subjectText'),
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
    );
  }
}
