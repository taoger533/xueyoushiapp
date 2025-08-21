import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'pages/publish_student_page.dart';
import 'pages/publish_teacher_page.dart';
import 'pages/student_list_page.dart';
import 'pages/teacher_list_page.dart';
import 'components/splash_redirector.dart';
import 'screens/reset_password_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashRedirector(),
  '/login': (context) => const LoginScreen(),
  '/register': (context) => const RegisterScreen(),
  '/home': (context) => const HomeScreen(),
  '/publish_student': (context) => const PublishStudentPage(),
  '/publish_teacher': (context) => const PublishTeacherPage(),

  // 学生列表 —— 线下（teachMethod: 线下 或 全部）
  '/students': (context) => const StudentListPage(isOnline: false),
  // 学生列表 —— 线上（teachMethod: 线上 或 全部）
  '/students_online': (context) => const StudentListPage(isOnline: true),

  // 教师列表 —— 线下（teachMethod: 线下 或 全部）
  '/teachers': (context) => const TeacherListPage(isOnline: false),
  // 教师列表 —— 线上（teachMethod: 线上 或 全部）
  '/teachers_online': (context) => const TeacherListPage(isOnline: true),
  '/reset-password': (context) => const ResetPasswordScreen(),
};