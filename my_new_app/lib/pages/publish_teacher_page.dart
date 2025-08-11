import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../components/local_draft_service.dart';
import '../components/teacher_profile_form.dart';
import '../components/area_selector.dart';
import 'dart:convert';
import '../utils/validators.dart';

class PublishTeacherPage extends StatefulWidget {
  const PublishTeacherPage({super.key});

  @override
  State<PublishTeacherPage> createState() => _PublishTeacherPageState();
}

class _PublishTeacherPageState extends State<PublishTeacherPage>
    with WidgetsBindingObserver {
  final GlobalKey<TeacherProfileFormState> _formKey =
      GlobalKey<TeacherProfileFormState>();

  String? userId;
  late LocalDraftService draftService;

  // —— 地区选择器状态
  String? _selectedProvince;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserIdAndDraft();
    _loadSelectedArea();  // ← 新增：初始加载本地地区
  }

  @override
  void dispose() {
    _saveLocalDraft();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveLocalDraft();
    }
    // ← 新增：从后台恢复时重新读取本地地区
    if (state == AppLifecycleState.resumed) {
      _loadSelectedArea();
    }
  }

  Future<void> _loadUserIdAndDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    setState(() => userId = id);
    if (id != null) {
      draftService = LocalDraftService(userId: id, type: 'teacher');
      await _loadLocalDraft();
    }
  }

  Future<void> _loadLocalDraft() async {
    if (userId == null) return;
    final data = await draftService.loadAll();
    if (data.isEmpty) return;

    List<Map<String, String>> parsedSubjects = [];
    if (data['subjects'] != null) {
      try {
        final rawList = jsonDecode(data['subjects']!);
        if (rawList is List) {
          parsedSubjects = List<Map<String, String>>.from(
            rawList.map((e) => Map<String, String>.from(e)),
          );
        }
      } catch (_) {}
    }

    _formKey.currentState?.setFields({
      'name': data['name'],
      'gender': data['gender'],
      'identity': data['identity'],
      'educationLevel': data['educationLevel'],
      'school': data['school'],
      'major': data['major'],
      'exp': data['exp'],
      'rateMin': data['rateMin'],
      'rateMax': data['rateMax'],
      'teachMethod': data['teachMethod'],
      'wechat': data['wechat'],
      'description': data['description'],
      'subjects': parsedSubjects,
    });
  }

  /// ← 新增：从 SharedPreferences 读取已选省市
  Future<void> _loadSelectedArea() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvince = prefs.getString('selected_province');
      _selectedCity = prefs.getString('selected_city');
    });
  }

  Future<void> _submitTeacherInfo() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final province = prefs.getString('selected_province');
    final city = prefs.getString('selected_city');

    if (province == null || city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择所在地区')),
      );
      return;
    }

    final teacher = _formKey.currentState?.collectData();
    if (teacher == null) return;

    await draftService.save(teacher.map((key, value) {
      if (key == 'subjects') {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value.toString());
    }));

    const fieldLabels = {
      'name': '称呼',
      'gender': '性别',
      'identity': '当前身份',
      'educationLevel': '最高学历',
      'school': '最高学历院校',
      'major': '专业',
      'exp': '教学经验',
      'rateMin': '报价下限',
      'rateMax': '报价上限',
      'teachMethod': '授课方式',
      'wechat': '微信号',
      'description': '个人自述',
    };

    for (final entry in fieldLabels.entries) {
      final raw = teacher[entry.key];
      final text = (raw == null ? '' : raw.toString()).trim();
      final error = FieldValidators.nonEmpty(fieldName: entry.value)(text);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }

    final subs = teacher['subjects'];
    if (subs is List && subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('授课科目不能为空')),
      );
      return;
    }

    teacher['userId'] = userId;
    teacher['province'] = province;
    teacher['city'] = city;

    try {
      final checkUrl = Uri.parse('$apiBase/api/teachers/user/$userId');
      final checkResp = await http.get(checkUrl);

      late http.Response response;
      if (checkResp.statusCode == 200) {
        final existing = jsonDecode(checkResp.body);
        final existingId = existing['_id'] as String;
        final putUrl = Uri.parse('$apiBase/api/teachers/$existingId');
        response = await http.put(
          putUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(teacher),
        );
      } else {
        final postUrl = Uri.parse('$apiBase/api/teachers');
        response = await http.post(
          postUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(teacher),
        );
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(checkResp.statusCode == 200
                ? '教员信息已更新'
                : '教员信息已发布'),
          ),
        );
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? '操作失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络错误：$e')),
      );
    }
  }

  Future<void> _saveLocalDraft() async {
    if (userId == null) return;
    final data = _formKey.currentState?.collectData(saveEmpty: true);
    if (data != null) {
      await draftService.save(data.map((key, value) {
        if (key == 'subjects') {
          return MapEntry(key, jsonEncode(value));
        }
        return MapEntry(key, value.toString());
      }));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('信息已保存到本地')),
      );
    }
  }

  Future<void> _clearLocalDraft() async {
    if (userId == null) return;
    await draftService.clear([
      'name',
      'gender',
      'identity',
      'educationLevel',
      'school',
      'major',
      'exp',
      'subjects',
      'rateMin',
      'rateMax',
      'teachMethod',
      'wechat',
      'description',
    ]);
    _formKey.currentState?.clearAllFields();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('草稿已清除')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveLocalDraft();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedProvince == null
                ? '登记教员信息'
                : '登记教员信息 ($_selectedProvince${_selectedCity != null ? '·$_selectedCity' : ''})',
          ),
          actions: [
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
                  },
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: TeacherProfileForm(
                  key: _formKey,
                  userId: userId,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitTeacherInfo,
                      child: const Text('发布'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saveLocalDraft,
                      child: const Text('保存到本地'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _clearLocalDraft,
                  child: const Text(
                    '清除草稿',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
