import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// 教师登记信息详情编辑页
class TeacherRegistrationDetailPage extends StatefulWidget {
  final String recordId;

  const TeacherRegistrationDetailPage({super.key, required this.recordId});

  @override
  State<TeacherRegistrationDetailPage> createState() => _TeacherRegistrationDetailPageState();
}

class _TeacherRegistrationDetailPageState extends State<TeacherRegistrationDetailPage> {
  bool isLoading = true;
  Map<String, dynamic> record = {};
  final Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('$apiBase/api/admin/teacher-registration/${widget.recordId}');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
        record = data;
        data.forEach((key, value) {
          if (key != '_id' && key != '__v') {
            controllers[key] = TextEditingController(text: value?.toString() ?? '');
          }
        });
      } else {
        debugPrint('获取教师登记信息失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  dynamic _convertValue(String key, String value) {
    final original = record[key];
    if (original is int) {
      return int.tryParse(value) ?? original;
    } else if (original is double) {
      return double.tryParse(value) ?? original;
    } else if (original is bool) {
      return value.toLowerCase() == 'true';
    }
    return value;
  }

  Future<void> _saveChanges() async {
    setState(() => isLoading = true);
    try {
      final Map<String, dynamic> updated = {};
      controllers.forEach((key, controller) {
        updated[key] = _convertValue(key, controller.text.trim());
      });
      final url = Uri.parse('$apiBase/api/admin/teacher-registration/${widget.recordId}');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updated),
      );
      if (resp.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context);
      } else {
        debugPrint('保存失败: ${resp.statusCode} ${resp.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${resp.body}')),
        );
      }
    } catch (e) {
      debugPrint('网络错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，请重试')),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教师登记信息详情')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text('ID: ${record['_id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...controllers.entries.map((entry) {
                    final key = entry.key;
                    final controller = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: controller,
                          decoration: InputDecoration(labelText: key),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
