import 'package:flutter/material.dart';
import 'subject_selector.dart';

class TeacherProfileForm extends StatefulWidget {
  final String? userId;
  const TeacherProfileForm({super.key, required this.userId});

  @override
  State<TeacherProfileForm> createState() => TeacherProfileFormState();
}

class TeacherProfileFormState extends State<TeacherProfileForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  String? gender;
  String? identity;
  String? educationLevel;
  String? teachMethod;
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController expController = TextEditingController();
  final TextEditingController rateMinController = TextEditingController();
  final TextEditingController rateMaxController = TextEditingController();
  final TextEditingController wechatController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // Key for the SubjectSelector
  final GlobalKey<SubjectSelectorState> _subjectKey = GlobalKey<SubjectSelectorState>();

  Map<String, dynamic> collectData({bool saveEmpty = false}) {
    return {
      'name': nameController.text.trim(),
      'gender': gender,
      'identity': identity,
      'educationLevel': educationLevel,
      'school': schoolController.text.trim(),
      'major': majorController.text.trim(),
      'exp': expController.text.trim(),
      'subjects': _subjectKey.currentState?.getSubjectPairs() ?? [],
      'rateMin': rateMinController.text.trim(),
      'rateMax': rateMaxController.text.trim(),
      'teachMethod': teachMethod,
      'wechat': wechatController.text.trim(),
      'description': descriptionController.text.trim(),
    };
  }

  /// 清空所有字段
  void clearAllFields() {
    nameController.clear();
    gender = null;
    identity = null;
    educationLevel = null;
    schoolController.clear();
    majorController.clear();
    expController.clear();
    rateMinController.clear();
    rateMaxController.clear();
    teachMethod = null;
    wechatController.clear();
    descriptionController.clear();
    // 清空授课科目选择
    _subjectKey.currentState?.setSubjectPairs([]);
    setState(() {});
  }

  /// 将已有数据填入表单
  void setFields(Map<String, dynamic> data) {
    nameController.text = (data['name'] ?? '').toString();
    gender = data['gender'];
    identity = data['identity'];
    educationLevel = data['educationLevel'];
    schoolController.text = (data['school'] ?? '').toString();
    majorController.text = (data['major'] ?? '').toString();
    expController.text = (data['exp'] ?? '').toString();
    rateMinController.text = (data['rateMin'] ?? '').toString();
    rateMaxController.text = (data['rateMax'] ?? '').toString();
    teachMethod = data['teachMethod'];
    wechatController.text = (data['wechat'] ?? '').toString();
    descriptionController.text = (data['description'] ?? '').toString();

    if (data['subjects'] is List) {
      final parsed = (data['subjects'] as List)
          .whereType<Map>()
          .map<Map<String, String>>((item) => {
                'phase': item['phase']?.toString() ?? '',
                'subject': item['subject']?.toString() ?? '',
              })
          .toList();
      // 恢复授课科目选择
      _subjectKey.currentState?.setSubjectPairs(parsed);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // 称呼
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '称呼'),
            maxLength: 5,
          ),
          // 性别
          DropdownButtonFormField<String>(
            value: ['男', '女'].contains(gender) ? gender : null,
            items: ['男', '女']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => gender = v),
            decoration: const InputDecoration(labelText: '性别'),
          ),
          // 当前身份
          DropdownButtonFormField<String>(
            value: [
              '高中毕业生',
              '在读大学生',
              '大四毕业生',
              '在读研究生'
            ].contains(identity)
                ? identity
                : null,
            items: [
              '高中毕业生',
              '在读大学生',
              '大四毕业生',
              '在读研究生'
            ]
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => identity = v),
            decoration: const InputDecoration(labelText: '当前身份'),
          ),
          // 最高学历
          DropdownButtonFormField<String>(
            value: ['学士', '硕士', '博士'].contains(educationLevel)
                ? educationLevel
                : null,
            items: ['学士', '硕士', '博士']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => educationLevel = v),
            decoration: const InputDecoration(labelText: '最高学历'),
          ),
          // 院校
          TextFormField(
            controller: schoolController,
            maxLength: 15,
            decoration: const InputDecoration(labelText: '最高学历院校'),
          ),
          // 专业
          TextFormField(
            controller: majorController,
            maxLength: 10,
            decoration: const InputDecoration(labelText: '专业'),
          ),
          // 教学经验
          TextFormField(
            controller: expController,
            keyboardType: TextInputType.number,
            maxLength: 2,
            decoration: const InputDecoration(labelText: '教学经验（年）'),
          ),
          const SizedBox(height: 12),
          // 科目选择器：最多选 10 组
          SubjectSelector(
            key: _subjectKey,
            maxPairs: 10,
          ),
          const SizedBox(height: 12),
          // 报价范围
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: rateMinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '报价下限'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: rateMaxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '报价上限'),
                ),
              ),
            ],
          ),
          // 授课方式
          DropdownButtonFormField<String>(
            value: ['线上', '线下', '全部'].contains(teachMethod)
                ? teachMethod
                : null,
            items: ['线上', '线下', '全部']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => teachMethod = v),
            decoration: const InputDecoration(labelText: '授课方式'),
          ),
          const SizedBox(height: 12),
          // 微信号
          TextFormField(
            controller: wechatController,
            maxLength: 20,
            decoration: const InputDecoration(labelText: '微信号（不对外展示）'),
          ),
          // 个人自述
          TextFormField(
            controller: descriptionController,
            maxLength: 100,
            minLines: 5,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '个人自述',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
