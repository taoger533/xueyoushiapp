import 'package:flutter/material.dart';

class PendingReviewsScreen extends StatefulWidget {
  const PendingReviewsScreen({super.key});

  @override
  State<PendingReviewsScreen> createState() => _PendingReviewsScreenState();
}

class _PendingReviewsScreenState extends State<PendingReviewsScreen> {
  List<Map<String, dynamic>> _toReview = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    // TODO: 加载待评价的教师列表
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _toReview = [
        // 示例数据
        {'name': '王老师', 'subject': '英语·小学'},
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('待评价')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _toReview.isEmpty
              ? const Center(child: Text('暂无待评价教师'))
              : ListView.builder(
                  itemCount: _toReview.length,
                  itemBuilder: (context, i) {
                    final item = _toReview[i];
                    return ListTile(
                      title: Text(item['name'] ?? ''),
                      subtitle: Text(item['subject'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.rate_review),
                        onPressed: () {
                          // TODO: 跳转到评价页面，传入教师信息
                        },
                      ),
                    );
                  },
                ),
    );
  }
}