import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config.dart';

/// 订单数据模型，包含学生和教师名称及其 ID
class Order {
  final String id;
  final String studentName;
  final String teacherName;

  Order({
    required this.id,
    required this.studentName,
    required this.teacherName,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> student =
        (json['student'] ?? {}) as Map<String, dynamic>;
    final Map<String, dynamic> teacher =
        (json['teacher'] ?? {}) as Map<String, dynamic>;
    return Order(
      id: (json['_id'] ?? '') as String,
      studentName: (student['name'] ?? '') as String,
      teacherName: (teacher['name'] ?? '') as String,
    );
  }
}

/// 订单管理页面，展示所有已确认订单，并支持删除
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order> orders = [];
  bool isLoading = true;

  /// 获取订单列表
  Future<void> fetchOrders() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('$apiBase/api/admin/orders');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        orders =
            data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        debugPrint('获取订单列表失败: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  /// 确认删除订单
  void confirmDeleteOrder(Order order) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该订单吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await deleteOrder(order);
    }
  }

  /// 删除订单
  Future<void> deleteOrder(Order order) async {
    try {
      final url = Uri.parse('$apiBase/api/admin/order/${order.id}');
      final resp = await http.delete(url);
      if (resp.statusCode == 200) {
        setState(() => orders.removeWhere((o) => o.id == order.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('订单已删除')),
        );
      } else {
        debugPrint('删除失败: ${resp.statusCode} ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败')),
        );
      }
    } catch (e) {
      debugPrint('网络错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络错误，删除失败')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('订单管理')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchOrders,
              child: ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      title:
                          Text('${order.studentName} - ${order.teacherName}'),
                      subtitle: Text('订单ID: ${order.id}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => confirmDeleteOrder(order),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
