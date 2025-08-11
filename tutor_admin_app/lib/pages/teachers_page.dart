import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; // 引入你的配置文件

class Teacher {
  final String id;
  final String username;
  bool isMember;
  int titleCode;
  List<String> titles;

  Teacher({
    required this.id,
    required this.username,
    required this.isMember,
    required this.titleCode,
    required this.titles,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      isMember: json['isMember'] ?? false,
      titleCode: json['titleCode'] ?? 0,
      titles: (json['titles'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  List<Teacher> teachers = [];
  bool isLoading = true;

  /// 教师头衔枚举
  final Map<int, String> titleCodeMap = {
    0: '普通教员',
    1: '专业教员',
    2: '学霸大学生',
    3: '专业教员 + 学霸大学生',
  };

  /// 获取教师列表
  Future<void> fetchTeachers() async {
    setState(() => isLoading = true);
    try {
      final resp = await http.get(Uri.parse('$apiBase/api/admin/teachers'));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        teachers = data.map((e) => Teacher.fromJson(e)).toList();
      } else {
        debugPrint('获取教师列表失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  /// 更新会员状态
  Future<void> updateMembership(Teacher teacher, bool value) async {
    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/api/admin/user/${teacher.id}/membership'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isMember': value}),
      );
      if (resp.statusCode == 200) {
        setState(() => teacher.isMember = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 ${teacher.username} 的会员状态修改为 ${value ? "会员" : "非会员"}')),
        );
      } else {
        debugPrint('更新失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
  }

  /// 编辑教师头衔（titleCode）
  void editTitles(Teacher teacher) async {
    int selectedCode = teacher.titleCode;

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑教师头衔'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: titleCodeMap.entries.map((entry) {
                return RadioListTile<int>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: selectedCode,
                  onChanged: (val) => setState(() => selectedCode = val!),
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selectedCode),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result != teacher.titleCode) {
      await updateTitleCode(teacher, result);
    }
  }

  /// 更新教师 titleCode
  Future<void> updateTitleCode(Teacher teacher, int code) async {
    try {
      final resp = await http.patch(
        Uri.parse('$apiBase/api/admin/user/${teacher.id}/title-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'titleCode': code}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          teacher.titleCode = data['titleCode'];
          teacher.titles = (data['titles'] as List).map((e) => e.toString()).toList();
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('头衔更新成功')));
      } else {
        debugPrint('更新头衔失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
  }

  /// 确认并删除教师
  void confirmDeleteTeacher(Teacher teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除教师 ${teacher.username} 吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteTeacher(teacher);
    }
  }

  /// 调用接口删除教师
  Future<void> deleteTeacher(Teacher teacher) async {
    try {
      final resp = await http.delete(Uri.parse('$apiBase/api/admin/user/${teacher.id}'));
      if (resp.statusCode == 200) {
        setState(() => teachers.removeWhere((t) => t.id == teacher.id));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已删除 ${teacher.username}')));
      } else {
        debugPrint('删除失败: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败')),
        );
      }
    } catch (e) {
      debugPrint('网络错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，删除失败')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchTeachers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教师管理')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchTeachers,
              child: ListView.builder(
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text('${teacher.username}'),
                      subtitle: Text('头衔: ${teacher.titles.join("、")}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: teacher.isMember,
                            onChanged: (value) => updateMembership(teacher, value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => editTitles(teacher),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => confirmDeleteTeacher(teacher),
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
