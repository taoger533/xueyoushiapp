import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentDetailPage({Key? key, required this.student}) : super(key: key);

  @override
  _StudentDetailPageState createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  int _teacherCount = 0;
  bool _loadingTeachers = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchTeacherCount();
  }

  Future<void> _fetchTeacherCount() async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/confirmedBookings/student/${widget.student['id']}'),
      );
      if (resp.statusCode == 200) {
        final List<dynamic> list = json.decode(resp.body);
        setState(() {
          _teacherCount = list.length;
          _loadingTeachers = false;
        });
      } else {
        setState(() {
          _errorMsg = '状态码 ${resp.statusCode}';
          _loadingTeachers = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = '网络异常';
        _loadingTeachers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 将科目列表格式化
    final subjectList = (widget.student['subjects'] as List<dynamic>)
        .map((e) => '${e['phase']} ${e['subject']}')
        .join('，');

    return Scaffold(
      appBar: AppBar(title: Text('学生详情：${widget.student['name']}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('姓名', widget.student['name']),
            _buildRow('性别', widget.student['gender']),
            _buildRow('省份', widget.student['province']),
            _buildRow('城市', widget.student['city']),
            _buildRow('地址', widget.student['region']),
            _buildRow('对教员性别要求', widget.student['tutorGender']),
            _buildRow('对教员身份要求', widget.student['tutorIdentity']),
            _buildRow('报价范围', '${widget.student['rateMin']}-${widget.student['rateMax']}'),
            _buildRow('上课时长', '${widget.student['duration']} 小时'),
            _buildRow('一周次数', '${widget.student['frequency']} 次'),
            _buildRow('学习科目', subjectList),
            _buildCountRow(),
            _buildRow('学员详细情况', widget.student['description']),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow() {
    String text;
    if (_loadingTeachers) {
      text = '加载中…';
    } else if (_errorMsg != null) {
      text = '错误：$_errorMsg';
    } else {
      text = '$_teacherCount';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 120,
            child: Text('当前老师总数：', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label：', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
