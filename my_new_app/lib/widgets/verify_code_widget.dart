import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerifyCodeWidget extends StatefulWidget {
  final String phone;
  final void Function(String code) onCodeGenerated;

  const VerifyCodeWidget({
    super.key,
    required this.phone,
    required this.onCodeGenerated,
  });

  @override
  State<VerifyCodeWidget> createState() => _VerifyCodeWidgetState();
}

class _VerifyCodeWidgetState extends State<VerifyCodeWidget> {
  int _secondsLeft = 0;
  int _requestCountToday = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadRequestCount();
  }

  Future<void> _loadRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final count = prefs.getInt('code_count_${widget.phone}_$today') ?? 0;
    setState(() => _requestCountToday = count);
  }

  Future<void> _incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().split(' ')[0];
    final key = 'code_count_${widget.phone}_$today';
    final newCount = _requestCountToday + 1;
    await prefs.setInt(key, newCount);
    setState(() => _requestCountToday = newCount);
  }

  void _startCooldown() {
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _sendCode() async {
    if (_requestCountToday >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日验证码请求次数已达上限')),
      );
      return;
    }

    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();
    widget.onCodeGenerated(code);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验证码已发送（模拟）：$code')),
    );

    _startCooldown();
    _incrementRequestCount();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _secondsLeft == 0 ? _sendCode : null,
      child: Text(
        _secondsLeft == 0
            ? '获取验证码'
            : '请等待 $_secondsLeft 秒后重试',
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

