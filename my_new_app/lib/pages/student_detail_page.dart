import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;
  const StudentDetailPage({super.key, required this.student});

  @override
  _StudentDetailPageState createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  /// 页面渲染用的学生对象：先用入参，随后按 userId 调 /api/students/user/:userId 刷新覆盖
  late Map<String, dynamic> _student;

  int _teacherCount = 0;
  bool _loadingTeachers = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _student = Map<String, dynamic>.from(widget.student);
    // 先统计老师数
    _fetchTeacherCount();
    // 再用和“教师页面一样”的方式按 userId 拉取学生详情并覆盖
    _refreshStudentDetailByUserId();
  }

  /// 和教师页面一致：仅按 userId 调 /api/students/user/:userId 获取详情，不做历史字段兼容
  Future<void> _refreshStudentDetailByUserId() async {
    final dynamic userIdDynamic = _student['userId'];
    final String userId = (userIdDynamic is String) ? userIdDynamic : userIdDynamic?.toString() ?? '';

    if (userId.isEmpty) {
      // 没有 userId 就不请求；保持用入参渲染
      return;
    }

    try {
      final resp = await http.get(Uri.parse('$apiBase/api/students/user/$userId'));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        Map<String, dynamic>? fresh;
        if (decoded is Map) {
          fresh = decoded.cast<String, dynamic>();
        } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          fresh = (decoded.first as Map).cast<String, dynamic>();
        }
        if (fresh != null) {
          setState(() {
            _student = fresh!;
          });
          // 刷新完详情之后，若 userId 未变则无需重新统计；如需稳妥可再调用一次统计：
          // await _fetchTeacherCount(); // 可选
        }
      } else {
        // 与教师页一致：这里不兜底历史字段、不再额外处理 404
        debugPrint('学生详情刷新失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('学生详情刷新异常: $e');
    }
  }

  Future<void> _fetchTeacherCount() async {
    // 后端按 student.userId 查询，这里仅取 userId（与教师页一致，不做历史字段兼容）
    final dynamic userIdDynamic = _student['userId'];

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
    final subjects = _student['subjects'];
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
      appBar: AppBar(title: Text('学生详情：${_student['name'] ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('姓名', (_student['name'] ?? '').toString()),
            _buildRow('性别', (_student['gender'] ?? '').toString()),
            _buildRow('省份', (_student['province'] ?? '').toString()),
            _buildRow('城市', (_student['city'] ?? '').toString()),
            _buildRow('地址', (_student['region'] ?? '').toString()),
            _buildRow('对教员性别要求', (_student['tutorGender'] ?? '').toString()),
            _buildRow('对教员身份要求', (_student['tutorIdentity'] ?? '').toString()),
            _buildRow(
              '报价范围',
              '${(_student['rateMin'] ?? '').toString()}-${(_student['rateMax'] ?? '').toString()}',
            ),
            _buildRow('上课时长', '${(_student['duration'] ?? '').toString()} 小时'),
            _buildRow('一周次数', '${(_student['frequency'] ?? '').toString()} 次'),
            _buildRow('学习科目', subjectList),
            _buildCountRow(),
            _buildRow('学员详细情况', (_student['description'] ?? '').toString()),
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
