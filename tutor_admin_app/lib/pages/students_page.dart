import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config.dart'; // 使用你的后端配置文件

class Student {
  final String id;
  final String username;
  bool isMember;

  Student({
    required this.id,
    required this.username,
    required this.isMember,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      isMember: json['isMember'] ?? false,
    );
  }
}

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Student> students = [];
  bool isLoading = true;

  /// 获取学生列表
  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('$apiBase/api/admin/students');
      debugPrint('请求学生列表: $url');

      final resp = await http.get(url);
      debugPrint('返回状态: ${resp.statusCode}');
      debugPrint('返回内容: ${resp.body}');

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        students = data.map((e) => Student.fromJson(e)).toList();
      } else {
        debugPrint('获取学生列表失败: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  /// 更新会员状态
  Future<void> updateMembership(Student student, bool value) async {
    try {
      final url = Uri.parse('$apiBase/api/admin/user/${student.id}/membership');
      debugPrint('更新会员状态: $url => $value');

      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isMember': value}),
      );

      debugPrint('返回状态: ${resp.statusCode}');
      debugPrint('返回内容: ${resp.body}');

      if (resp.statusCode == 200) {
        setState(() => student.isMember = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 ${student.username} 的会员状态修改为 ${value ? "会员" : "非会员"}')),
        );
      } else {
        debugPrint('更新失败: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
  }

  /// 删除学生
  void confirmDeleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除学生 ${student.username} 吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteStudent(student);
    }
  }

  Future<void> deleteStudent(Student student) async {
    try {
      final url = Uri.parse('$apiBase/api/admin/user/${student.id}');
      final resp = await http.delete(url);
      if (resp.statusCode == 200) {
        setState(() => students.removeWhere((s) => s.id == student.id));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已删除 ${student.username}')));
      } else {
        debugPrint('删除失败: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    } catch (e) {
      debugPrint('网络错误: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('网络错误，删除失败')));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学生管理')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchStudents,
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(student.username),
                      subtitle: Text('会员状态: ${student.isMember ? "会员" : "非会员"}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: student.isMember,
                            onChanged: (value) => updateMembership(student, value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => confirmDeleteStudent(student),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
