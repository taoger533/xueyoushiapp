import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 提前准备 SharedPreferences 可选
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? role = prefs.getString('user_role');

  // 如果你希望保留判断结果做调试，可以打印
  debugPrint('[main] 登录状态: $isLoggedIn, 角色: $role');

  runApp(const MyApp());
}
