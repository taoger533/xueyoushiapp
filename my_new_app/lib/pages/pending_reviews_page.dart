import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class PendingReviewsPage extends StatefulWidget {
  const PendingReviewsPage({super.key});

  @override
  State<PendingReviewsPage> createState() => _PendingReviewsPageState();
}

class _PendingReviewsPageState extends State<PendingReviewsPage> {
  bool loading = true;
  List<Map<String, dynamic>> items = [];
  String? userId;

  void _log(String msg) => debugPrint('[PendingReviews] $msg');

  @override
  void initState() {
    super.initState();
    _log('initState');
    fetchPending();
  }

  Future<void> fetchPending() async {
    _log('--- fetchPending START ---');
    try {
      final prefs = await SharedPreferences.getInstance();
      // 严格按你的方式：从 'user_id' 取
      userId = prefs.getString('user_id');
      _log('SharedPreferences.user_id = $userId');
      _log('apiBase = $apiBase');

      if (userId == null || userId!.trim().isEmpty) {
        _log('user_id 为空，直接返回');
        setState(() {
          loading = false;
          items = [];
        });
        return;
      }

      // 严格按你的方式：confirmed-bookings 路径（中横线）
      final url = '$apiBase/api/confirmed-bookings/$userId';
      _log('GET $url');

      http.Response resp;
      try {
        resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        _log('请求超时(15s): $url');
        if (mounted) {
          setState(() {
            loading = false;
            items = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请求超时，请稍后重试')),
          );
        }
        return;
      }

      _log('status = ${resp.statusCode}');
      _log('headers = ${resp.headers}');
      final bodyPreview =
          resp.body.length <= 1024 ? resp.body : resp.body.substring(0, 1024) + '...<truncated>';
      _log('body (<=1KB preview) = $bodyPreview');

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        _log('decoded runtimeType = ${decoded.runtimeType}');
        if (decoded is List) {
          _log('raw list length = ${decoded.length}');
          // 仅保留“我是学生”的记录
          final filtered = <Map<String, dynamic>>[];
          for (int i = 0; i < decoded.length; i++) {
            final m = Map<String, dynamic>.from(decoded[i] as Map);
            final student = (m['student'] ?? {}) as Map<String, dynamic>;
            final sid = (student['userId'] ?? '').toString();
            if (sid == userId) filtered.add(m);
          }
          _log('filtered (as student) length = ${filtered.length}');
          for (int i = 0; i < math.min(5, filtered.length); i++) {
            final m = filtered[i];
            final id = m['_id'] ?? m['id'];
            final teacher = (m['teacher'] ?? {}) as Map<String, dynamic>;
            final tName = teacher['name'];
            final tSubjects = teacher['subjects'];
            _log('#$i: _id=$id, teacher.name=$tName, subjectsType=${tSubjects.runtimeType}');
          }

          setState(() {
            items = filtered;
            loading = false;
          });
          _log('setState: items.length=${items.length}, loading=$loading');
        } else {
          _log('后端返回的不是 List，无法渲染。');
          if (!mounted) return;
          setState(() {
            loading = false;
            items = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据格式异常：不是列表')),
          );
        }
      } else {
        _log('非200状态码：${resp.statusCode}');
        if (!mounted) return;
        setState(() {
          loading = false;
          items = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：${resp.statusCode}')),
        );
      }
    } catch (e, st) {
      _log('异常: $e');
      _log('堆栈: $st');
      if (!mounted) return;
      setState(() {
        loading = false;
        items = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载异常：$e')),
      );
    } finally {
      _log('--- fetchPending END ---');
    }
  }

  String subjectLine(Map<String, dynamic>? teacher) {
    if (teacher == null) {
      _log('subjectLine teacher=null');
      return '';
    }
    final list = (teacher['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _log('subjectLine subjects.length=${list.length}');
    if (list.isEmpty) return '';
    final result = list
        .map((s) {
          final phase = s['phase']?.toString() ?? '';
          final subject = s['subject']?.toString() ?? '';
          _log('subject item -> phase="$phase", subject="$subject"');
          return '$phase$subject'.trim(); // 与你的示例一致，直接相连
        })
        .where((t) => t.isNotEmpty)
        .join('，');
    _log('subjectLine result="$result"');
    return result;
  }

  Future<void> openReview(Map<String, dynamic> booking) async {
    final id = booking['_id'] ?? booking['id'];
    final teacher = (booking['teacher'] ?? {}) as Map<String, dynamic>;
    _log('openReview bookingId=$id teacher.name=${teacher['name']}');
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _QuickReview(booking: booking)),
    );
    _log('openReview result ok=$ok');
    if (ok == true) {
      setState(() {
        items.removeWhere((e) => (e['_id'] ?? e['id']) == id);
      });
      _log('已从本地列表移除 id=$id，剩余=${items.length}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('评价已提交')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _log('build: loading=$loading items.length=${items.length}');
    return Scaffold(
      appBar: AppBar(title: const Text('待评价')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('暂无待评价教师'))
              : RefreshIndicator(
                  onRefresh: fetchPending,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final doc = items[i];
                      final teacher = (doc['teacher'] ?? {}) as Map<String, dynamic>;
                      final name = teacher['name']?.toString() ?? '老师';
                      final subline = subjectLine(teacher);
                      _log('build item #$i -> teacher.name="$name", subline="$subline"');

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(name),
                        subtitle: Text(subline.isEmpty ? '—' : subline),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.thumb_up_alt_outlined),
                          label: const Text('去评价'),
                          onPressed: () => openReview(doc),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _QuickReview extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _QuickReview({required this.booking});

  @override
  State<_QuickReview> createState() => _QuickReviewState();
}

class _QuickReviewState extends State<_QuickReview> {
  bool? like; // true=愿意给好评，false=暂不推荐
  bool submitting = false;

  void _log(String msg) => debugPrint('[QuickReview] $msg');

  String get teacherTitle {
    final t = (widget.booking['teacher'] ?? {}) as Map<String, dynamic>;
    final name = t['name']?.toString() ?? '老师';
    final subs = ((t['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [])
        .map((s) {
          final phase = (s['phase'] ?? '').toString();
          final subject = (s['subject'] ?? '').toString();
          return '$phase$subject'.trim(); // 与上面一致
        })
        .where((e) => e.isNotEmpty)
        .join('，');
    final result = subs.isEmpty ? name : '$name · $subs';
    _log('teacherTitle="$result"');
    return result;
  }

  Future<void> submit() async {
    if (like == null) {
      _log('提交被阻止：like==null');
      return;
    }
    setState(() => submitting = true);

    final id = widget.booking['_id'] ?? widget.booking['id'];
    // 严格按你的风格：confirmed-bookings（中横线）+ review 接口
    final url = '$apiBase/api/confirmed-bookings/$id/review';
    _log('POST $url, like=$like');

    try {
      http.Response resp;
      try {
        resp = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'like': like}),
            )
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        _log('评价请求超时(15s): $url');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交超时，请稍后重试')),
        );
        return;
      }

      _log('review status=${resp.statusCode}');
      final bodyPreview =
          resp.body.length <= 1024 ? resp.body : resp.body.substring(0, 1024) + '...<truncated>';
      _log('review body (<=1KB preview)=$bodyPreview');

      if (resp.statusCode == 200) {
        // 可选：解析返回的好评数并提示
        try {
          final data = json.decode(resp.body);
          final incremented = data['incremented'] == true;
          final count = data['goodReviewCount'];
          if (incremented && count is num) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已好评 +1（当前累计：$count）')),
            );
          }
        } catch (_) {}
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败：${resp.statusCode}')),
        );
      }
    } catch (e, st) {
      _log('评价异常: $e');
      _log('堆栈: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交异常：$e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
      _log('submit END');
    }
  }

  @override
  Widget build(BuildContext context) {
    _log('build: like=$like submitting=$submitting');
    return Scaffold(
      appBar: AppBar(title: const Text('快速评价')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(teacherTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('是否愿意给该教员一个好评？', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              value: true,
              groupValue: like,
              onChanged: (v) {
                _log('choose like=true');
                setState(() => like = v);
              },
              title: const Text('愿意给好评'),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: like,
              onChanged: (v) {
                _log('choose like=false');
                setState(() => like = v);
              },
              title: const Text('暂不推荐'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (like == null || submitting) ? null : submit,
                child: submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('提交'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
