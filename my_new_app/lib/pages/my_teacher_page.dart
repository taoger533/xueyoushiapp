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

      // 1. 获取所有与我相关的已确认预约
      final confirmedResp = await http.get(
        Uri.parse('$apiBase/api/confirmed-bookings/$_userId'),
      );
      if (confirmedResp.statusCode != 200) throw '获取预约失败';
      final confirmedList = jsonDecode(confirmedResp.body) as List;

      // 2. 遍历每条预约，筛选出“我是学生”的记录，然后取teacher.userId去拉教师详情
      final List<Map<String, dynamic>> teachers = [];
      for (var item in confirmedList) {
        if (item['student']['userId'] == _userId) {
          final String teacherId = item['teacher']['userId'];
          final detailResp = await http.get(
            Uri.parse('$apiBase/api/teachers?userId=$teacherId'),
          );
          if (detailResp.statusCode == 200) {
            final data = jsonDecode(detailResp.body);
            if (data is List && data.isNotEmpty) {
              teachers.add(Map<String, dynamic>.from(data.first));
            }
          }
        }
      }

      setState(() => _teachers = teachers);
    } catch (e) {
      debugPrint('加载教师失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的老师')),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _teachers.isEmpty
              ? const Center(child: Text('暂无已确认的教员'))
              : ListView.builder(
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final tea = _teachers[index];
                    final subjectText = (tea['subjects'] as List)
                        .map((e) => '${e['phase']}${e['subject']}')
                        .join('，');
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(tea['name'] ?? ''),
                        subtitle: Text('科目：$subjectText'),
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
    );
  }
}
