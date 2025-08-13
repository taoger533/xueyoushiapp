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
    // 后端按 student.userId 查询，这里优先取 userId
    final dynamic userIdDynamic = widget.student['userId'] ??
        widget.student['user_id'] ??
        widget.student['publisherId'];

    if (userIdDynamic == null || userIdDynamic.toString().trim().isEmpty) {
      setState(() {
        _errorMsg = '缺少 userId（无法统计老师数量）';
        _loadingTeachers = false;
      });
      return;
    }

    final String userId = userIdDynamic.toString();

    try {
      // 注意：confirmed-bookings（有连字符）
      final uri = Uri.parse('$apiBase/api/confirmed-bookings/student/$userId');
      final resp = await http.get(uri);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = resp.body.trim();
        if (body.isEmpty) {
          setState(() {
            _teacherCount = 0;
            _loadingTeachers = false;
          });
          return;
        }

        final decoded = json.decode(body);

        int count = 0;
        if (decoded is List) {
          count = decoded.length;
        } else if (decoded is Map<String, dynamic>) {
          // 兼容返回 { count, items } 或直接 { items: [...] }
          if (decoded['count'] is int) {
            count = decoded['count'] as int;
          } else if (decoded['items'] is List) {
            count = (decoded['items'] as List).length;
          } else {
            // 不认识的结构，当成 0
            count = 0;
          }
        }

        setState(() {
          _teacherCount = count;
          _loadingTeachers = false;
          _errorMsg = null;
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
    // 将科目列表格式化（空值保护）
    String subjectList = '';
    final subjects = widget.student['subjects'];
    if (subjects is List) {
      subjectList = subjects
          .map((e) {
            if (e is Map) {
              final phase = (e['phase'] ?? '').toString();
              final subject = (e['subject'] ?? '').toString();
              if (phase.isEmpty && subject.isEmpty) return null;
              return [phase, subject].where((s) => s.isNotEmpty).join(' ');
            }
            return null;
          })
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .join('，');
    }

    return Scaffold(
      appBar: AppBar(title: Text('学生详情：${widget.student['name'] ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('姓名', (widget.student['name'] ?? '').toString()),
            _buildRow('性别', (widget.student['gender'] ?? '').toString()),
            _buildRow('省份', (widget.student['province'] ?? '').toString()),
            _buildRow('城市', (widget.student['city'] ?? '').toString()),
            _buildRow('地址', (widget.student['region'] ?? '').toString()),
            _buildRow('对教员性别要求', (widget.student['tutorGender'] ?? '').toString()),
            _buildRow('对教员身份要求', (widget.student['tutorIdentity'] ?? '').toString()),
            _buildRow(
              '报价范围',
              '${(widget.student['rateMin'] ?? '').toString()}-${(widget.student['rateMax'] ?? '').toString()}',
            ),
            _buildRow('上课时长', '${(widget.student['duration'] ?? '').toString()} 小时'),
            _buildRow('一周次数', '${(widget.student['frequency'] ?? '').toString()} 次'),
            _buildRow('学习科目', subjectList),
            _buildCountRow(),
            _buildRow('学员详细情况', (widget.student['description'] ?? '').toString()),
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
