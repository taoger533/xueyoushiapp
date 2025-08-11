import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class PaymentPage extends StatefulWidget {
  /// 支付场景 ID
  final String scenarioId;

  const PaymentPage({super.key, required this.scenarioId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _loading = true; // 场景信息加载中
  bool _processing = false; // 支付进行中
  double? _amount;
  String? _description;
  String? _error;

  String? _userId; // 从后端获取到的用户ID

  final List<String> paymentMethods = ['微信支付', '支付宝支付'];

  @override
  void initState() {
    super.initState();
    _loadUserIdAndPaymentInfo();
  }

  /// 同时获取 userId 和支付场景信息
  Future<void> _loadUserIdAndPaymentInfo() async {
    try {
      // 1️⃣ 获取本地用户ID用于请求后端（这里仅作为索引用）
      final prefs = await SharedPreferences.getInstance();
      final localUserId = prefs.getString('user_id');
      if (localUserId == null) {
        setState(() {
          _error = '未登录用户';
          _loading = false;
        });
        return;
      }

      // 2️⃣ 从后端获取真实用户信息
            final userResp = await http.get(Uri.parse('$apiBase/api/user-info/$localUserId'));
              if (userResp.statusCode == 200) {
                // 只确认请求成功，不使用返回数据
                _userId = localUserId;
              } else {

        setState(() {
          _error = '获取用户信息失败，状态码 ${userResp.statusCode}';
          _loading = false;
        });
        return;
      }

      // 3️⃣ 获取支付场景信息
      final resp = await http.get(
        Uri.parse('$apiBase/api/payment/scenario/${widget.scenarioId}'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _amount = (data['amount'] as num).toDouble();
          _description = data['description'] as String;
          _loading = false;
        });
      } else {
        setState(() {
          _error = '获取支付信息失败：状态码 ${resp.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '获取支付信息异常：$e';
        _loading = false;
      });
    }
  }

  Future<void> _processPayment(String method) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未获取到用户ID，无法支付')));
      return;
    }

    setState(() {
      _processing = true;
    });

    // 模拟支付延时
    await Future.delayed(const Duration(seconds: 2));

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/api/payment/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'scenarioId': widget.scenarioId,
          'method': method,
          'userId': _userId, // ✅ 从后端接口获得
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('状态码 ${resp.statusCode}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$method 模拟支付成功，支付金额：￥${_amount?.toStringAsFixed(2) ?? '-'}'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('通知服务器失败：$e')));
      setState(() {
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支付')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('场景：${_description!}', style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      Text('应付金额：￥${_amount!.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      const Text('请选择支付方式',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...paymentMethods.map((method) {
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                method == '微信支付'
                                    ? Icons.payment
                                    : Icons.account_balance_wallet,
                                color: method == '微信支付' ? Colors.green : Colors.blue,
                              ),
                              title: Text(method),
                              onTap: _processing ? null : () => _processPayment(method),
                            ),
                            const Divider(),
                          ],
                        );
                      }).toList(),
                      const Spacer(),
                      if (_processing) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 12),
                        const Center(child: Text('正在处理支付……')),
                      ] else ...[
                        const Center(
                          child: Text('支付完成后将自动生效', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}
