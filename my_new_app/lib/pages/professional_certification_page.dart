import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/image_upload_box.dart';

class ProfessionalCertificationPage extends StatefulWidget {
  const ProfessionalCertificationPage({super.key});

  @override
  State<ProfessionalCertificationPage> createState() => _ProfessionalCertificationPageState();
}

class _ProfessionalCertificationPageState extends State<ProfessionalCertificationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();

  String? _idFrontUrl;
  String? _idBackUrl;
  String? _certificateUrl;

  @override
  void dispose() {
    _schoolController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idFrontUrl == null || _idBackUrl == null || _certificateUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传所有必需的图片')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录用户')),
      );
      return;
    }

    final resp = await http.post(
      Uri.parse('$apiBase/api/professional-certification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'school': _schoolController.text.trim(),
        'major': _majorController.text.trim(),
        'idFrontUrl': _idFrontUrl,
        'idBackUrl': _idBackUrl,
        'certificateUrl': _certificateUrl,
      }),
    );

    if (resp.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('认证申请提交成功')),
      );
      Navigator.pop(context, true);
    } else {
      final err = jsonDecode(resp.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：${err['error'] ?? '未知错误'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('专业教员认证')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: '毕业院校',
                  border: OutlineInputBorder(),
                ),
                maxLength: 15,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入毕业院校';
                  if (v.length > 15) return '最多15字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _majorController,
                decoration: const InputDecoration(
                  labelText: '专业',
                  border: OutlineInputBorder(),
                ),
                maxLength: 10,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入专业';
                  if (v.length > 10) return '最多10字';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 虚线框 + 加号 上传：身份证人像面
              ImageUploadBox(
                label: '身份证人像面',
                onUploaded: (url) {
                  _idFrontUrl = url;
                },
              ),
              const SizedBox(height: 16),
              // 虚线框 + 加号 上传：身份证国徽面
              ImageUploadBox(
                label: '身份证国徽面',
                onUploaded: (url) {
                  _idBackUrl = url;
                },
              ),
              const SizedBox(height: 16),
              // 虚线框 + 加号 上传：学生证或教师资格证
              ImageUploadBox(
                label: '学生证或教师资格证',
                onUploaded: (url) {
                  _certificateUrl = url;
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('提交认证'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
