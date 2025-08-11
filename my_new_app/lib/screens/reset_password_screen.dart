import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  String? _selectedRole;
  String? _generatedCode;
  int _secondsLeft = 0;
  int _requestCountToday = 0;
  Timer? _timer;
  bool _isSending = false;

  bool _isValidPhone(String phone) {
    final regex = RegExp(r'^1[3-9]\d{9}$');
    return regex.hasMatch(phone);
  }

  bool _isValidPassword(String pwd) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,16}$');
    return regex.hasMatch(pwd);
  }

  Future<void> _loadRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final count = prefs.getInt('reset_code_count_$today') ?? 0;
    setState(() => _requestCountToday = count);
  }

  Future<void> _incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final key = 'reset_code_count_$today';
    final newCount = _requestCountToday + 1;
    await prefs.setInt(key, newCount);
    setState(() => _requestCountToday = newCount);
  }

  Future<bool> _checkPhoneRegistered(String phone, String role) async {
    try {
      final url = Uri.parse('$apiBase/api/check-phone');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'role': role}),
      );
      final data = jsonDecode(res.body);
      return data['exists'] == true;
    } catch (_) {
      return false;
    }
  }

  void _startCooldown() {
    setState(() => _secondsLeft = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择身份')),
      );
      return;
    }
    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法手机号')),
      );
      return;
    }

    setState(() => _isSending = true);

    final exists = await _checkPhoneRegistered(phone, _selectedRole!);
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该手机号未注册此身份')),
      );
      setState(() => _isSending = false);
      return;
    }

    if (_requestCountToday >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日验证码获取已达上限')),
      );
      setState(() => _isSending = false);
      return;
    }

    final code = (100000 + Random().nextInt(900000)).toString();
    _generatedCode = code;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验证码已发送（模拟）：$code')),
    );

    _startCooldown();
    await _incrementRequestCount();
    setState(() => _isSending = false);
  }

  Future<void> _submitReset() async {
    final phone = _phoneController.text.trim();
    final inputCode = _codeController.text.trim();
    final newPwd = _newPasswordController.text;

    if (phone.isEmpty || inputCode.isEmpty || newPwd.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写所有字段')),
      );
      return;
    }

    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法手机号')),
      );
      return;
    }

    if (inputCode != _generatedCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码错误')),
      );
      return;
    }

    if (!_isValidPassword(newPwd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码需8~16位，含大小写字母和数字')),
      );
      return;
    }

    try {
      final url = Uri.parse('$apiBase/api/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'role': _selectedRole,
          'newPassword': newPwd,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码重置成功，请重新登录')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失败：${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误：$e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRequestCount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('找回密码')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
              onChanged: (_) => _loadRequestCount(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('选择身份：'),
                Checkbox(
                  value: _selectedRole == 'student',
                  onChanged: (value) {
                    if (value!) setState(() => _selectedRole = 'student');
                    else if (_selectedRole == 'student') setState(() => _selectedRole = null);
                  },
                ),
                const Text('学生'),
                Checkbox(
                  value: _selectedRole == 'teacher',
                  onChanged: (value) {
                    if (value!) setState(() => _selectedRole = 'teacher');
                    else if (_selectedRole == 'teacher') setState(() => _selectedRole = null);
                  },
                ),
                const Text('教员'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '验证码'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_secondsLeft == 0 && !_isSending) ? _sendCode : null,
                  child: Text(_secondsLeft == 0 ? '获取验证码' : '$_secondsLeft 秒后重试'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码（8~16位，含大小写字母和数字）',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitReset,
              child: const Text('确认重置密码'),
            ),
          ],
        ),
      ),
    );
  }
}
