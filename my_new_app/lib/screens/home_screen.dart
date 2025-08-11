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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchBannerImages(); // 首次加载
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
      _fetchBannerImages(); // 唤醒时刷新
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

        if (_bannerImages.isNotEmpty) {
          _startAutoScroll();
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
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
      setState(() {
        _currentPage = nextPage;
      });
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
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部轮播公告
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
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final fullUrl = '$apiBase${_bannerImages[index]}';
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                fullUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.broken_image));
                                },
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
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == i ? Colors.orange : Colors.white70,
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
        ),

        // 主功能按钮
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.role == 'teacher') ...[
                  // 教师身份：学生列表合并为一个入口（页内 Tab 切换线上/线下）
                  Row(
                    children: [
                      buildWideButton(
                        text: '学生列表（合并）',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentListPage(
                                // 仅控制进入页面时默认选中标签；进入后可在页内切换
                                isOnline: false, // 默认先显示线下，可改 true 为默认线上
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/publish_teacher'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: const Color.fromARGB(255, 241, 173, 26),
                    ),
                    child: const Text('登记教员信息'),
                  ),
                ] else if (widget.role == 'student') ...[
                  // 学生身份：老师列表合并为一个入口（页内 Tab 切换线上/线下）
                  Row(
                    children: [
                      buildWideButton(
                        text: '老师列表（合并）',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(
                                // 仅控制进入页面时默认选中标签；进入后可在页内切换
                                isOnline: false, // 默认先显示线下，可改 true 为默认线上
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 快捷筛选：专业教员/学霸大学生（进入后仍可在页内切换线上/线下）
                  Row(
                    children: [
                      buildWideButton(
                        text: '专业教员列表',
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          const filter = 1;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(
                                isOnline: false,
                                titleFilter: filter,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '学霸大学生',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          const filter = 2;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(
                                isOnline: false,
                                titleFilter: filter,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/publish_student'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('登记学生信息'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
