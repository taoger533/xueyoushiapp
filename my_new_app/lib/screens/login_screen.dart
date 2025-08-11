import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedRole;
  bool _agreedToTerms = false;

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择身份')),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读并同意用户服务协议')),
      );
      return;
    }

    try {
      final url = Uri.parse('$apiBase/api/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': _selectedRole,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final role = data['role'];
        final userId = data['userId'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('username', username);
        await prefs.setString('user_role', role);
        await prefs.setString('user_id', userId);

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? '登录失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '手机号'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reset-password');
                  },
                  child: const Text('忘记密码？'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('选择身份：'),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: _selectedRole == 'student',
                    onChanged: (value) {
                      if (value!) {
                        setState(() => _selectedRole = 'student');
                      } else if (_selectedRole == 'student') {
                        setState(() => _selectedRole = null);
                      }
                    },
                  ),
                  const Text('学生'),
                  Checkbox(
                    value: _selectedRole == 'teacher',
                    onChanged: (value) {
                      if (value!) {
                        setState(() => _selectedRole = 'teacher');
                      } else if (_selectedRole == 'teacher') {
                        setState(() => _selectedRole = null);
                      }
                    },
                  ),
                  const Text('教员'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() => _agreedToTerms = value ?? false);
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // 可选：弹窗或跳转协议页面
                      },
                      child: const Text(
                        '我已阅读并同意《用户服务协议》',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('登录'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
