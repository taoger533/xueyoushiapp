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

  // 网格筛选科目
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
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  /// 网格筛选器
  Widget _buildSubjectGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _subjects.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // 每行4个
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.6,
        ),
        itemBuilder: (_, i) {
          final s = _subjects[i];
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // 根据身份跳转到对应列表页并带上 subject 参数
              if (widget.role == 'student') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherListPage(
                      isOnline: false,
                      // TeacherListPage 中要接收 subject 参数
                      // 需要你那边 TeacherListPage 构造函数支持 subject
                      // 如果没加，先加上
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentListPage(
                      isOnline: false,
                      // 同上，支持 subject
                    ),
                  ),
                );
              }
            },
            child: Text(s),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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

          const SizedBox(height: 12),

          // 主功能按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              children: [
                if (widget.role == 'teacher') ...[
                  Row(
                    children: [
                      buildWideButton(
                        text: '学生列表（合并）',
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
                  // 网格筛选器
                  _buildSubjectGrid(),
                ] else if (widget.role == 'student') ...[
                  Row(
                    children: [
                      buildWideButton(
                        text: '老师列表（合并）',
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
                  // 额外分类按钮
                  Row(
                    children: [
                      buildWideButton(
                        text: '普通教员列表',
                        backgroundColor: Colors.grey,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(isOnline: false, titleFilter: 0),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      buildWideButton(
                        text: '专业教员列表',
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherListPage(isOnline: false, titleFilter: 1),
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
                              builder: (_) => const TeacherListPage(isOnline: false, titleFilter: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // 网格筛选器
                  _buildSubjectGrid(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
