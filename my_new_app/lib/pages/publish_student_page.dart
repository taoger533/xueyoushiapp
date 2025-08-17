import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config.dart';
import '../components/local_draft_service.dart';
import '../components/student_profile_form.dart';
import '../components/area_selector.dart';  // ← 新增
import '../utils/validators.dart';

class PublishStudentPage extends StatefulWidget {
  const PublishStudentPage({super.key});

  @override
  State<PublishStudentPage> createState() => _PublishStudentPageState();
}

class _PublishStudentPageState extends State<PublishStudentPage>
    with WidgetsBindingObserver {
  final GlobalKey<StudentProfileFormState> _formKey =
      GlobalKey<StudentProfileFormState>();

  String? userId;
  late LocalDraftService draftService;
  bool _isPublic = false; // 新增：公开选项，初始为未选中

  // —— 新增：地区选择器状态
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
    if (state == AppLifecycleState.resumed) {
      _loadSelectedArea();  // ← 新增：恢复时重新读取本地地区
    }
  }

  Future<void> _loadUserIdAndDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    setState(() {
      userId = id;
    });
    if (id != null) {
      draftService = LocalDraftService(userId: id, type: 'student');
      final data = await draftService.loadAll();
      if (data.isNotEmpty) {
        // 解析公开选项
        final pub = data['isPublic'];
        setState(() {
          _isPublic = pub == 'true';
        });
        // 解析其他草稿字段
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
          'tutorGender': data['tutorGender'],
          'tutorIdentity': data['tutorIdentity'],
          'rateMin': data['rateMin'],
          'rateMax': data['rateMax'],
          'duration': data['duration'],
          'frequency': data['frequency'],
          'teachMethod': data['teachMethod'],
          'region': data['region'],
          'wechat': data['wechat'],
          'description': data['description'],
          'subjects': parsedSubjects,
        });
      }
    }
  }

  /// ← 新增：从 SharedPreferences 读取已选省市
  Future<void> _loadSelectedArea() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedProvince = prefs.getString('selected_province');
      _selectedCity = prefs.getString('selected_city');
    });
  }

  Future<void> _submitStudentInfo() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户未登录')),
      );
      return;
    }

    final formData = _formKey.currentState?.collectData();
    if (formData == null) return;

    // teachMethod 用于决定是否需要地区（线上不强制）
    final teachMethod = (formData['teachMethod'] ?? '').toString().trim();

    // 仅当 teachMethod != '线上' 时才要求必须选择地区
    String? province;
    String? city;
    if (teachMethod != '线上') {
      final prefs = await SharedPreferences.getInstance();
      province = prefs.getString('selected_province');
      city = prefs.getString('selected_city');

      if (province == null || city == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择所在地区')),
        );
        return;
      }
    }

    // 注入公开选项和地区、userId（线上时允许 province/city 为空）
    formData['isPublic'] = _isPublic;
    formData['userId'] = userId;
    if (province != null) formData['province'] = province;
    if (city != null) formData['city'] = city;

    // 保存草稿
    await draftService.save(formData.map((key, value) {
      if (key == 'subjects') {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value.toString());
    }));

    // 非空校验（描述、科目等）
    const fieldLabels = {
      'name': '称呼',
      'gender': '学员性别',
      'tutorGender': '对教员性别要求',
      'tutorIdentity': '对教员身份要求',
      'rateMin': '报价下限',
      'rateMax': '报价上限',
      'duration': '上课时长',
      'frequency': '一周次数',
      'teachMethod': '授课方式',
      'region': '授课地区',
      'wechat': '微信号',
      'description': '学员详细情况',
    };
    for (final entry in fieldLabels.entries) {
      // teachMethod 为“线上”时，region 可不校验；但为了兼容原有逻辑，这里只在键为 region 且 teachMethod == '线上' 时跳过
      if (entry.key == 'region' && teachMethod == '线上') continue;

      final text = (formData[entry.key] ?? '').toString().trim();
      final error = FieldValidators.nonEmpty(fieldName: entry.value)(text);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    // subjects 单独校验
    final subs = formData['subjects'];
    if (subs is List && subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学习科目不能为空')),
      );
      return;
    }

    try {
      // 检测已有记录
      final checkUrl = Uri.parse('$apiBase/api/students/user/$userId');
      final checkResp = await http.get(checkUrl);

      late http.Response response;
      bool isUpdate = false;

      if (checkResp.statusCode == 200) {
        // 更新
        isUpdate = true;
        final existing = jsonDecode(checkResp.body);
        final existingId = existing['_id'] as String;
        final putUrl = Uri.parse('$apiBase/api/students/$existingId');
        response = await http.put(
          putUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );
      } else {
        // 新建
        final postUrl = Uri.parse('$apiBase/api/students');
        response = await http.post(
          postUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(formData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 解析后端返回的审核信息
        String reviewStatus = '';
        String reviewMessage = '';
        try {
          final respJson = jsonDecode(response.body);
          reviewStatus = (respJson['reviewStatus'] ?? '').toString();
          reviewMessage = (respJson['reviewMessage'] ?? '').toString();
        } catch (_) {}

        final baseMsg = isUpdate ? '需求信息已更新' : '需求信息已发布';
        String reviewPart = '';
        if (reviewStatus.isNotEmpty) {
          if (reviewStatus == 'approved') {
            reviewPart = '（审核：通过）';
          } else if (reviewStatus == 'rejected') {
            // 如果被拒绝，带上简短原因
            reviewPart = reviewMessage.isNotEmpty
                ? '（审核：驳回，$reviewMessage）'
                : '（审核：驳回）';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$baseMsg$reviewPart')),
        );

        // 若被驳回，可选：额外弹窗详细原因（保留草稿）
        if (reviewStatus == 'rejected' && reviewMessage.isNotEmpty) {
          // 只提示，不阻止返回；你也可以选择不返回上一页
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('自动审核结果'),
              content: Text(reviewMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('我知道了'),
                ),
              ],
            ),
          );
        }

        Navigator.pop(context);
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['error'] ?? '操作失败')),
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
      data['isPublic'] = _isPublic; // 保存公开状态
      await draftService.save(data.map((key, value) {
        if (key == 'subjects') {
          return MapEntry(key, jsonEncode(value));
        }
        return MapEntry(key, value.toString());
      }));
      // 这里会在返回/切后台也触发，频繁提示可能打扰；若不想提示可去掉这段 SnackBar
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
      'tutorGender',
      'tutorIdentity',
      'subjects',
      'rateMin',
      'rateMax',
      'duration',
      'frequency',
      'teachMethod',
      'region',
      'wechat',
      'description',
      'isPublic', // 清除公开状态
    ]);
    setState(() {
      _isPublic = false;
    });
    _formKey.currentState?.clearAllFields();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('草稿已清除')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 动态计算 AppBar 标题，使用 _selectedProvince/_selectedCity 避免未使用警告
    String titleText;
    if (_selectedProvince != null) {
      final cityPart = _selectedCity != null ? '·$_selectedCity' : '';
      titleText = '发布家教需求 ($_selectedProvince$cityPart)';
    } else {
      titleText = '发布家教需求';
    }

    return WillPopScope(
      onWillPop: () async {
        await _saveLocalDraft();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
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
                child: StudentProfileForm(key: _formKey, userId: userId),
              ),
              const SizedBox(height: 12),
              // 新增：是否公开复选框
              CheckboxListTile(
                title: const Text('是否公开'),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitStudentInfo,
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
                  child: const Text('清除草稿',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
