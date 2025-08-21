import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/legal_doc_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _selectedRole = '';
  bool _agreedToTerms = false;

  String? _generatedCode;
  int _secondsLeft = 0;
  Timer? _cooldownTimer;
  int _requestCountToday = 0;

  @override
  void initState() {
    super.initState();
    _loadRequestCount();
  }

  bool _isValidPhone(String phone) {
    final regex = RegExp(r'^1[3-9]\d{9}$');
    return regex.hasMatch(phone);
  }

  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,16}$');
    return regex.hasMatch(password);
  }

  Future<void> _loadRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    final today = DateTime.now().toString().split(' ')[0];
    final count = prefs.getInt('code_count_${phone}_$today') ?? 0;
    setState(() => _requestCountToday = count);
  }

  Future<void> _incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = _phoneController.text.trim();
    final today = DateTime.now().toString().split(' ')[0];
    final key = 'code_count_${phone}_$today';
    final newCount = _requestCountToday + 1;
    await prefs.setInt(key, newCount);
    setState(() => _requestCountToday = newCount);
  }

  void _startCooldown() {
    setState(() => _secondsLeft = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法的11位手机号')),
      );
      return;
    }

    if (_requestCountToday >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日验证码获取已达上限（5次）')),
      );
      return;
    }

    final code = (100000 + Random().nextInt(900000)).toString();
    setState(() => _generatedCode = code);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验证码已发送（模拟）：$code')),
    );

    _startCooldown();
    await _incrementRequestCount();
  }

  void _handleRegister() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final inputCode = _codeController.text.trim();

    if (phone.isEmpty || password.isEmpty || confirmPassword.isEmpty || inputCode.isEmpty || _selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写所有字段')),
      );
      return;
    }

    if (!_isValidPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入合法的11位手机号')),
      );
      return;
    }

    if (inputCode != _generatedCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码错误')),
      );
      return;
    }

    if (!_isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码需为8~16位，包含数字和字母')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次密码输入不一致')),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读并同意用户服务协议')),
      );
      return;
    }

    final url = Uri.parse('$apiBase/api/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': phone,
          'password': password,
          'role': _selectedRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        final loginUrl = Uri.parse('$apiBase/api/login');
        final loginResp = await http.post(
          loginUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': phone,
            'password': password,
            'role': _selectedRole,
          }),
        );

        if (loginResp.statusCode == 200) {
          final loginData = jsonDecode(loginResp.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('username', phone);
          await prefs.setString('user_role', loginData['role']);
          await prefs.setString('user_id', loginData['userId']);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册并自动登录成功')),
          );

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('注册成功，但自动登录失败')),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? '注册失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误：$e')),
      );
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
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
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '验证码'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _secondsLeft == 0 ? _sendCode : null,
                    child: Text(_secondsLeft == 0 ? '获取验证码' : '$_secondsLeft 秒后重试'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码（8~16位，数字和字母组合）'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: _selectedRole == 'student',
                    onChanged: (value) {
                      if (value!) {
                        setState(() => _selectedRole = 'student');
                      } else if (_selectedRole == 'student') {
                        setState(() => _selectedRole = '');
                      }
                    },
                  ),
                  const Text('学生'),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: _selectedRole == 'teacher',
                    onChanged: (value) {
                      if (value!) {
                        setState(() => _selectedRole = 'teacher');
                      } else if (_selectedRole == 'teacher') {
                        setState(() => _selectedRole = '');
                      }
                    },
                  ),
                  const Text('教员'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) {
                      setState(() {
                        _agreedToTerms = v ?? false;
                      });
                    },
                  ),
                  const Text('我已阅读并同意 '),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalDocPage(type: 'terms'),
                        ),
                      );
                    },
                    child: const Text(
                      '《用户服务协议》',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const Text(' 和 '),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalDocPage(type: 'privacy'),
                        ),
                      );
                    },
                    child: const Text(
                      '《隐私政策》',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleRegister,
                child: const Text('注册'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('已有账号？返回登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}