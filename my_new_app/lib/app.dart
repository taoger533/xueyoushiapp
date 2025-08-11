import 'package:flutter/material.dart';
import 'routes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '家教App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',         // 始终从 '/'（SplashRedirector）启动
      routes: appRoutes,         // 保留你的路由管理
    );
  }
}
