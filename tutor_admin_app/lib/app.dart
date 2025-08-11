import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

class TutorAdminApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;

  const TutorAdminApp({super.key, required this.isLoggedIn, this.role});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家教管理端',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? DashboardPage(role: role) : const LoginPage(),
    );
  }
}
