import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../pages/teacher_list_page.dart';
import '../pages/student_list_page.dart';

class HomeTab extends StatefulWidget {
  final String role;
  const HomeTab({super.key, required this.role});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  List<String> _bannerImages = [];
  bool _loading = true;

  // 首页科目：与列表页筛选条保持一致
  static const List<String> _subjects = [
    '数学','英语','语文','物理','化学',
    '生物','地理','历史','政治','作文',
    '奥数','钢琴','电子琴','古筝','竹笛',
    '美术','日语','德语','法语','韩语',
    '俄语','雅思','托福','计算机','英语口语',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchBannerImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchBannerImages();
    }
  }

  Future<void> _fetchBannerImages() async {
    try {
      final response = await http.get(Uri.parse('$apiBase/api/banners'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _bannerImages = data.map((e) => e as String).toList();
          _loading = false;
        });
        if (_bannerImages.isNotEmpty) _startAutoScroll();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (_bannerImages.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % _bannerImages.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = nextPage);
    });
  }

  Widget buildWideButton({
    required String text,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 2,
          shadowColor: Colors.black12,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  void _onSubjectTap(String subject) {
    // 把选中的科目传给对应列表页
    if (widget.role == 'student') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherListPage(
            isOnline: false,
            subject: subject, // ← 传递
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentListPage(
            isOnline: false,
            subject: subject, // ← 传递
          ),
        ),
      );
    }
  }

  Widget _buildSubjectSection() {
    final cs = Theme.of(context).colorScheme;
    return Card
    (
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 6),
                Text('按科目快速筛选',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _onSubjectTap('全部'),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('全部'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 12,
              children: _subjects
                  .map((s) => _SubjectPill(label: s, onTap: () => _onSubjectTap(s)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bannerImages.isEmpty
                  ? const Center(child: Text('暂无公告'))
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _bannerImages.length,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemBuilder: (context, index) {
                            final fullUrl = '$apiBase${_bannerImages[index]}';
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                fullUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (_, __, ___) =>
                                    const Center(child: Icon(Icons.broken_image)),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_bannerImages.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentPage == i ? 10 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentPage == i
                                      ? cs.primary
                                      : cs.onPrimary.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
        ),

        // 主功能 + 科目筛选卡片
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                if (widget.role == 'teacher') ...[
                  Row(
                    children: [
                      buildWideButton(
                        text: '学员库）',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentListPage(isOnline: false),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '登记教员信息',
                        backgroundColor: const Color.fromARGB(255, 241, 173, 26),
                        onPressed: () => Navigator.pushNamed(context, '/publish_teacher'),
                      ),
                    ],
                  ),
                  _buildSubjectSection(),
                ] else if (widget.role == 'student') ...[
                  Row(
                    children: [
                      buildWideButton(
                        text: '教员库',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(isOnline: false),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '登记学生信息',
                        backgroundColor: Colors.orange,
                        onPressed: () => Navigator.pushNamed(context, '/publish_student'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      buildWideButton(
                        text: '普通教员',
                        backgroundColor: Colors.grey,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TeacherListPage(isOnline: false, titleFilter: 0),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '专业教员',
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TeacherListPage(isOnline: false, titleFilter: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '学霸大学生',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TeacherListPage(isOnline: false, titleFilter: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSubjectSection(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SubjectPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 1.1,
              color: cs.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
