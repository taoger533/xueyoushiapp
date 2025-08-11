import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? role = prefs.getString('user_role'); // admin / operator

  runApp(TutorAdminApp(
    isLoggedIn: isLoggedIn,
    role: role,
  ));
}
