import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class PaymentPage extends StatefulWidget {
  /// 支付场景 ID（变量名不变）
  final String scenarioId;

  /// 可选：数量/时长（不改动既有变量名，仅新增可选项）
  final int? quantity; // 次数（认证类）
  final int? months;   // 学生会员按月
  final int? years;    // 教师会员按年

  const PaymentPage({
    super.key,
    required this.scenarioId,
    this.quantity,
    this.months,
    this.years,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? userId;               // 变量名不变（来源：后端）
  String method = 'alipay';     // 变量名不变，只允许 alipay
  int? amount;                  // 单价
  String? description;

  // 本页可编辑的数量/时长（若外部有传，则以外部为初始值）
  late int _quantity;
  late int _months;
  late int _years;

  // 推断单位：times / months / years
  late String _unitType;

  bool _loading = true;
  bool _processing = false;
  String? _error;

  // —— 调试相关 —— //
  final List<String> _logs = [];
  bool _showLogs = false;

  void _log(String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    setState(() => _logs.add('[$t] $msg'));
    // 同时打印到控制台便于 adb logcat 查看
    // ignore: avoid_print
    print('[PaymentPage] $msg');
  }

  String _abbr(dynamic v, {int max = 300}) {
    final s = v is String ? v : jsonEncode(v);
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...(${s.length} chars)';
  }

  @override
  void initState() {
    super.initState();
    _unitType = _inferUnitType(widget.scenarioId, widget.quantity, widget.months, widget.years);
    _quantity = (widget.quantity ?? 1).clamp(1, 9999);
    _months   = (widget.months   ?? 1).clamp(1, 120);
    _years    = (widget.years    ?? 1).clamp(1, 10);
    _initAndFetch();
  }

  String _inferUnitType(String scenarioId, int? q, int? m, int? y) {
    if (m != null) return 'months';
    if (y != null) return 'years';
    if (q != null) return 'times';
    if (scenarioId == 'member_student') return 'months';
    if (scenarioId == 'member_teacher') return 'years';
    return 'times';
  }

  int get _multiplier {
    switch (_unitType) {
      case 'months': return _months;
      case 'years':  return _years;
      default:       return _quantity;
    }
  }

  int get _total {
    if (amount == null) return 0;
    return amount! * _multiplier;
  }

  Future<void> _initAndFetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _logs.clear();
    });

    try {
      // 1) 取 token → 请求 “当前用户”，拿 userId
      final id = await _fetchCurrentUserIdFromBackend();
      _log('得到 userId=${id ?? "null"}');
      if (id == null || id.isEmpty) {
        setState(() {
          _error = '未登录或缺少 userId';
          _loading = false;
        });
        return;
      }
      userId = id;

      // 2) 获取场景信息（单价 + 描述）
      final headers = await _authHeadersIfAny() ?? {'Content-Type': 'application/json'};
      _log('GET 场景信息 headers=${_abbr(headers)}');
      final resp = await http.get(
        Uri.parse('$apiBase/api/payment/scenario/${widget.scenarioId}'),
        headers: headers,
      );
      _log('GET 场景信息 status=${resp.statusCode}');
      _log('GET 场景信息 body=${_abbr(resp.body)}');

      if (resp.statusCode != 200) {
        setState(() {
          _error = '获取支付场景失败（${resp.statusCode}）';
          _loading = false;
        });
        return;
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      setState(() {
        amount = (data['amount'] as num).toInt();
        description = data['description']?.toString();
        _loading = false;
      });
    } catch (e) {
      _log('初始化异常: $e');
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  /// 从后端读取当前登录用户，返回 userId（支持 id/_id/userId）
  Future<String?> _fetchCurrentUserIdFromBackend() async {
    final headers = await _authHeadersIfAny();
    _log('准备获取当前用户 headers=${_abbr(headers)}');

    if (headers == null) {
      _log('未找到 token，无法请求当前用户接口');
      return null;
    }

    // 依次尝试多个常见“当前用户”接口，取第一个可用的
    final candidates = <Uri>[
      Uri.parse('$apiBase/api/auth/me'),
      Uri.parse('$apiBase/api/user/me'),
      Uri.parse('$apiBase/api/user-info/me'),
    ];

    for (final uri in candidates) {
      try {
        _log('GET $uri');
        final r = await http.get(uri, headers: headers);
        _log('→ status=${r.statusCode}');
        _log('→ body=${_abbr(r.body)}');

        if (r.statusCode == 200) {
          final j = json.decode(r.body);
          if (j is Map) {
            final id = _pickId(j);
            _log('→ 解析到 id=${id ?? "null"}');
            if (id != null && id.toString().isNotEmpty) {
              return id.toString();
            }
          }
        } else if (r.statusCode == 401) {
          _log('→ 未授权(401)，token 可能无效');
          return null;
        }
      } catch (e) {
        _log('→ 请求异常: $e');
      }
    }
    return null;
  }

  /// 从一个 Map 中挑选出 id/_id/userId
  String? _pickId(Map data) {
    final v = data['id'] ?? data['_id'] ?? data['userId'];
    return v?.toString();
  }

  /// 若登录时保存了 token，则拼出鉴权头；否则返回 null
  Future<Map<String, String>?> _authHeadersIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    // ① 常见：Bearer token
    final token = prefs.getString('token') ?? prefs.getString('authToken');
    if (token != null && token.isNotEmpty) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    }
    // ② 如果你项目用的是 cookie 会话，这里可以返回 null，让 http 走无头部请求（但默认 http 包不带 cookie）
    return null;
  }

  Future<void> _processPayment() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // 仍使用原有字段名 scenarioId / userId / method
      final body = <String, dynamic>{
        'scenarioId': widget.scenarioId,
        'userId': userId,
        'method': method, // 仅 alipay
      };
      if (_unitType == 'times')  body['quantity'] = _quantity;
      if (_unitType == 'months') body['months']   = _months;
      if (_unitType == 'years')  body['years']    = _years;

      final headers = await _authHeadersIfAny() ?? {'Content-Type': 'application/json'};
      _log('POST /api/payment/confirm headers=${_abbr(headers)}');
      _log('POST /api/payment/confirm body=${_abbr(body)}');

      final resp = await http.post(
        Uri.parse('$apiBase/api/payment/confirm'),
        headers: headers,
        body: json.encode(body),
      );

      _log('支付结果 status=${resp.statusCode}');
      _log('支付结果 body=${_abbr(resp.body)}');

      if (resp.statusCode != 200) {
        final msg = _safeErr(resp.body);
        setState(() {
          _error = '支付失败：HTTP ${resp.statusCode} $msg';
          _processing = false;
        });
        return;
      }

      final res = json.decode(resp.body) as Map<String, dynamic>;
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? '支付成功')),
      );

      Navigator.of(context).pop(true); // 返回上一页并标记成功
    } catch (e) {
      _log('支付异常: $e');
      setState(() {
        _error = '支付异常：$e';
        _processing = false;
      });
    }
  }

  String _safeErr(String raw) {
    try {
      final j = json.decode(raw);
      final s = (j is Map && j['error'] != null) ? j['error'].toString() : raw;
      return s.length > 200 ? '${s.substring(0, 200)}...' : s;
    } catch (_) {
      return raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = description == null ? '支付' : '支付 - $description';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_error != null)
                    FilledButton.tonal(
                      onPressed: _initAndFetch,
                      child: const Text('重试'),
                    ),
                  if (_error == null) ...[
                    if (description != null)
                      Text('项目：$description', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    if (amount != null)
                      Text('单价：¥$amount', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 12),
                    _buildUnitEditorCard(),
                    const SizedBox(height: 12),
                    _buildTotalCard(),
                    const SizedBox(height: 24),
                    const Text('选择支付方式', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet,
                        color: method == 'alipay' ? Colors.blue : null,
                      ),
                      title: const Text('支付宝支付'),
                      trailing: Radio<String>(
                        value: 'alipay',
                        groupValue: method,
                        onChanged: _processing
                            ? null
                            : (v) => setState(() => method = v ?? 'alipay'),
                      ),
                      onTap: _processing
                          ? null
                          : () => setState(() => method = 'alipay'),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _processing ? null : _processPayment,
                        child: _processing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('立即支付'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // —— 调试信息面板 —— //
                  InkWell(
                    onTap: () => setState(() => _showLogs = !_showLogs),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(_showLogs ? '隐藏调试信息' : '显示调试信息',
                            style: const TextStyle(decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_showLogs)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (_, i) => Text(
                            _logs[i],
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // —— UI 片段 —— //

  Widget _buildUnitEditorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(_unitLabel, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(
              onPressed: _processing ? null : () => _dec(),
              icon: const Icon(Icons.remove),
            ),
            Text('$_multiplier', style: const TextStyle(fontSize: 18)),
            IconButton(
              onPressed: _processing ? null : () => _inc(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      child: ListTile(
        title: const Text('合计'),
        subtitle: Text('$_unitLabel × 单价'),
        trailing: Text(
          '¥$_total',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String get _unitLabel {
    switch (_unitType) {
      case 'months': return '时长（月）';
      case 'years':  return '时长（年）';
      default:       return '数量（次）';
    }
  }

  void _inc() {
    setState(() {
      if (_unitType == 'months') {
        if (_months < 120) _months++;
      } else if (_unitType == 'years') {
        if (_years < 10) _years++;
      } else {
        if (_quantity < 9999) _quantity++;
      }
    });
  }

  void _dec() {
    setState(() {
      if (_unitType == 'months') {
        if (_months > 1) _months--;
      } else if (_unitType == 'years') {
        if (_years > 1) _years--;
      } else {
        if (_quantity > 1) _quantity--;
      }
    });
  }
}
