import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'payment_page.dart';

/// 支付订单页：展示项目/单价，并选择数量或时长，计算合计后跳转支付页
class PaymentOrderPage extends StatefulWidget {
  /// 保持变量名风格一致：沿用 scenarioId
  final String scenarioId;

  const PaymentOrderPage({super.key, required this.scenarioId});

  @override
  State<PaymentOrderPage> createState() => _PaymentOrderPageState();
}

class _PaymentOrderPageState extends State<PaymentOrderPage> {
  bool _loading = true;
  String? _error;

  int? _unitAmount;        // 单价（单位金额）
  String? _description;    // 场景描述

  // 购买参数（按不同场景使用其一）
  int _quantity = 1;       // 次数（适用：认证类）
  int _months = 1;         // 月数（适用：学生会员）
  int _years = 1;          // 年数（适用：教师会员）

  // 推断的单位类型：times / months / years
  late final String _unitType;

  @override
  void initState() {
    super.initState();
    _unitType = _inferUnitType(widget.scenarioId);
    _fetchScenario();
  }

  String _inferUnitType(String scenarioId) {
    // 规则：你可以根据后端约定自由扩展
    if (scenarioId == 'member_student') return 'months';
    if (scenarioId == 'member_teacher') return 'years';
    return 'times'; // professional_certification / top_student_certification
  }

  Future<void> _fetchScenario() async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/payment/scenario/${widget.scenarioId}'),
      );
      if (resp.statusCode != 200) {
        setState(() {
          _error = '获取支付项目失败（${resp.statusCode}）';
          _loading = false;
        });
        return;
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      setState(() {
        _unitAmount = (data['amount'] as num).toInt();
        _description = data['description']?.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  int get _total {
    if (_unitAmount == null) return 0;
    switch (_unitType) {
      case 'months':
        return _unitAmount! * _months;
      case 'years':
        return _unitAmount! * _years;
      case 'times':
      default:
        return _unitAmount! * _quantity;
    }
  }

  Widget _buildUnitEditor() {
    switch (_unitType) {
      case 'months':
        return _NumberEditor(
          label: '时长（月）',
          value: _months,
          min: 1,
          max: 36,
          onChanged: (v) => setState(() => _months = v),
        );
      case 'years':
        return _NumberEditor(
          label: '时长（年）',
          value: _years,
          min: 1,
          max: 5,
          onChanged: (v) => setState(() => _years = v),
        );
      case 'times':
      default:
        return _NumberEditor(
          label: '数量（次）',
          value: _quantity,
          min: 1,
          max: 20,
          onChanged: (v) => setState(() => _quantity = v),
        );
    }
  }

  Future<void> _goPay() async {
    // 跳转到已有 PaymentPage，保持原变量名不变
    // 仅“新增可选参数”传入（quantity / months / years），PaymentPage 会原样带给后端
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          scenarioId: widget.scenarioId,
          // 以下均为新增可选参数，不影响原有使用
          quantity: _unitType == 'times' ? _quantity : null,
          months: _unitType == 'months' ? _months : null,
          years: _unitType == 'years' ? _years : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '支付订单';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _fetchScenario,
                        child: const Text('重试'),
                      )
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 项目信息
                      Card(
                        child: ListTile(
                          title: Text(_description ?? '支付项目'),
                          subtitle: Text('场景ID：${widget.scenarioId}'),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 单价
                      Card(
                        child: ListTile(
                          title: const Text('单价'),
                          trailing: Text(
                            _unitAmount == null ? '--' : '¥$_unitAmount',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 数量/时长编辑器
                      Card(child: Padding(padding: const EdgeInsets.all(8), child: _buildUnitEditor())),
                      const SizedBox(height: 8),

                      // 合计
                      Card(
                        child: ListTile(
                          title: const Text('合计'),
                          trailing: Text(
                            '¥$_total',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _unitAmount == null ? null : _goPay,
                          child: const Text('去支付'),
                        ),
                      )
                    ],
                  ),
      ),
    );
  }
}

/// 简单的数字步进器
class _NumberEditor extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberEditor({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const Spacer(),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$value', style: const TextStyle(fontSize: 18)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
