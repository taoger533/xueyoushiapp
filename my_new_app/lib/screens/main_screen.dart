import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'message_screen.dart';
import 'home_screen.dart';
import 'my_screen.dart';
import '../components/area_selector.dart';

/// 应用主界面：包含“首页”、“消息”、“我的”三页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _role = '';
  String? _selectedProvince;
  String? _selectedCity;

  final List<String> _titles = [
    '首页',
    '消息',
    '我的',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRole();
    _loadSelectedArea();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台切回前台时刷新地区信息
    if (state == AppLifecycleState.resumed) {
      _loadSelectedArea();
    }
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('user_role') ?? '';
    });
  }

  Future<void> _loadSelectedArea() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvince = prefs.getString('selected_province');
      _selectedCity = prefs.getString('selected_city');
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomeTab(role: _role),
      const MessageScreen(),
      const MyScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // 始终只显示“首页”、“消息”或“我的”，无额外文字
        title: Text(_titles[_currentIndex]),
        actions: _currentIndex == 0
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: AreaSelector(
                      onSelected: (province, city) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('selected_province', province);
                        await prefs.setString('selected_city', city);
                        setState(() {
                          _selectedProvince = province;
                          _selectedCity = city;
                        });
                        debugPrint('选择了：$province $city');
                      },
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: '消息'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
