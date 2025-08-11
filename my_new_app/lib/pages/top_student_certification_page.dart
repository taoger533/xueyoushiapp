import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../widgets/image_upload_box.dart';
import '../pages/payment_page.dart'; // 引入支付页

class TopStudentCertificationPage extends StatefulWidget {
  const TopStudentCertificationPage({super.key});

  @override
  State<TopStudentCertificationPage> createState() => _TopStudentCertificationPageState();
}

class _TopStudentCertificationPageState extends State<TopStudentCertificationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();

  String? _idFrontUrl;
  String? _idBackUrl;
  String? _studentIdUrl;
  String? _suppUrl1;
  String? _suppUrl2;
  String? _suppUrl3;

  @override
  void dispose() {
    _universityController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idFrontUrl == null || _idBackUrl == null || _studentIdUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请上传身份证人像面、国徽面及学生证')),
      );
      return;
    }
    // 至少一张佐证材料
    if (_suppUrl1 == null && _suppUrl2 == null && _suppUrl3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少上传一张佐证材料')),
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

    // 1️⃣ 先进行支付
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PaymentPage(scenarioId: 'top_student_certification'),
      ),
    );

    if (paid != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('支付未完成，认证未提交')),
      );
      return;
    }

    // 2️⃣ 支付成功后提交表单
    final body = {
      'userId': userId,
      'university': _universityController.text.trim(),
      'major': _majorController.text.trim(),
      'idFrontUrl': _idFrontUrl,
      'idBackUrl': _idBackUrl,
      'studentIdUrl': _studentIdUrl,
      'suppUrls': [
        if (_suppUrl1 != null) _suppUrl1,
        if (_suppUrl2 != null) _suppUrl2,
        if (_suppUrl3 != null) _suppUrl3,
      ],
    };

    final resp = await http.post(
      Uri.parse('$apiBase/api/top-student-certification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
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
      appBar: AppBar(title: const Text('学霸大学生认证')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _universityController,
                decoration: const InputDecoration(
                  labelText: '当前院校',
                  border: OutlineInputBorder(),
                ),
                maxLength: 15,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入当前院校';
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
              // 身份证人像面
              ImageUploadBox(
                label: '身份证人像面',
                onUploaded: (url) {
                  _idFrontUrl = url;
                },
              ),
              const SizedBox(height: 16),
              // 身份证国徽面
              ImageUploadBox(
                label: '身份证国徽面',
                onUploaded: (url) {
                  _idBackUrl = url;
                },
              ),
              const SizedBox(height: 16),
              // 学生证
              ImageUploadBox(
                label: '学生证',
                onUploaded: (url) {
                  _studentIdUrl = url;
                },
              ),
              const SizedBox(height: 16),
              // 佐证材料（最多三张）
              ImageUploadBox(
                label: '佐证材料 1',
                onUploaded: (url) {
                  _suppUrl1 = url;
                },
              ),
              const SizedBox(height: 16),
              ImageUploadBox(
                label: '佐证材料 2',
                onUploaded: (url) {
                  _suppUrl2 = url;
                },
              ),
              const SizedBox(height: 16),
              ImageUploadBox(
                label: '佐证材料 3',
                onUploaded: (url) {
                  _suppUrl3 = url;
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('提交认证'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
