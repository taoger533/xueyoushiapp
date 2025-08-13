import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'teacher_registration_detail_page.dart';

/// 教师登记信息列表页
class TeacherRegistrationsPage extends StatefulWidget {
  const TeacherRegistrationsPage({super.key});

  @override
  State<TeacherRegistrationsPage> createState() => _TeacherRegistrationsPageState();
}

class _TeacherRegistrationsPageState extends State<TeacherRegistrationsPage> {
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRegistrations();
  }

  Future<void> fetchRegistrations() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('$apiBase/api/admin/teacher-registrations');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        records = data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        debugPrint('获取教师登记信息失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  String getDisplayName(Map<String, dynamic> record) {
    final fields = ['realName', 'name', 'username', 'teacherName', 'phone'];
    for (final f in fields) {
      if (record.containsKey(f) && record[f] != null && record[f].toString().isNotEmpty) {
        return record[f].toString();
      }
    }
    return record['_id']?.toString() ?? '';
  }

  Future<void> deleteRecord(String id) async {
    try {
      final url = Uri.parse('$apiBase/api/admin/teacher-registration/$id');
      final resp = await http.delete(url);
      if (resp.statusCode == 200) {
        setState(() => records.removeWhere((r) => r['_id'] == id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功')),
        );
      } else {
        debugPrint('删除教师登记信息失败: ${resp.statusCode} ${resp.body}');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教师登记信息管理')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchRegistrations,
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final id = record['_id']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text(getDisplayName(record)),
                      subtitle: Text('ID: $id'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherRegistrationDetailPage(recordId: id),
                          ),
                        );
                        fetchRegistrations();
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteRecord(id),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
