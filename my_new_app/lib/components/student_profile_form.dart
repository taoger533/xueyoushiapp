import 'package:flutter/material.dart';
import 'subject_selector.dart';

class StudentProfileForm extends StatefulWidget {
  final String? userId;
  const StudentProfileForm({Key? key, required this.userId}) : super(key: key);

  @override
  State<StudentProfileForm> createState() => StudentProfileFormState();
}

class StudentProfileFormState extends State<StudentProfileForm> {
  final _formKey = GlobalKey<FormState>();

  // 基本信息控制器
  final TextEditingController nameController = TextEditingController();
  String? gender;
  String? tutorGender;
  String? tutorIdentity;
  String? teachMethod;
  final TextEditingController rateMinController = TextEditingController();
  final TextEditingController rateMaxController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController regionController = TextEditingController();
  final TextEditingController wechatController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // 科目选择器的 Key
  final GlobalKey<SubjectSelectorState> _subjectKey =
      GlobalKey<SubjectSelectorState>();

  /// 收集所有表单数据（包括所选科目）
  Map<String, dynamic> collectData({bool saveEmpty = false}) {
    final subjects = _subjectKey.currentState?.getSubjectPairs() ?? [];
    return {
      'name': nameController.text.trim(),
      'gender': gender,
      'tutorGender': tutorGender,
      'tutorIdentity': tutorIdentity,
      'rateMin': rateMinController.text.trim(),
      'rateMax': rateMaxController.text.trim(),
      'duration': durationController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'teachMethod': teachMethod,
      'region': regionController.text.trim(),
      'wechat': wechatController.text.trim(),
      'description': descriptionController.text.trim(),
      'subjects': subjects,
    };
  }

  /// 清空所有字段
  void clearAllFields() {
    nameController.clear();
    gender = null;
    tutorGender = null;
    tutorIdentity = null;
    rateMinController.clear();
    rateMaxController.clear();
    durationController.clear();
    frequencyController.clear();
    teachMethod = null;
    regionController.clear();
    wechatController.clear();
    descriptionController.clear();
    _subjectKey.currentState?.setSubjectPairs([]);
    setState(() {});
  }

  /// 根据已有数据回填表单
  void setFields(Map<String, dynamic> data) {
    nameController.text = (data['name'] ?? '').toString();
    gender = data['gender'];
    tutorGender = data['tutorGender'];
    tutorIdentity = data['tutorIdentity'];
    rateMinController.text = (data['rateMin'] ?? '').toString();
    rateMaxController.text = (data['rateMax'] ?? '').toString();
    durationController.text = (data['duration'] ?? '').toString();
    frequencyController.text = (data['frequency'] ?? '').toString();
    teachMethod = data['teachMethod'];
    regionController.text = (data['region'] ?? '').toString();
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
      _subjectKey.currentState?.setSubjectPairs(parsed);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 学员称呼
          TextFormField(
            controller: nameController,
            maxLength: 5,
            decoration: const InputDecoration(labelText: '学员称呼'),
          ),

          // 学员性别
          DropdownButtonFormField<String>(
            value: ['男', '女'].contains(gender) ? gender : null,
            items: ['男', '女']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => gender = v),
            decoration: const InputDecoration(labelText: '学员性别'),
          ),

          // 对教员性别要求
          DropdownButtonFormField<String>(
            value: ['男', '女', '无'].contains(tutorGender)
                ? tutorGender
                : null,
            items: ['男', '女', '无']
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => tutorGender = v),
            decoration: const InputDecoration(labelText: '对教员性别要求'),
          ),

          // 对教员身份要求
          DropdownButtonFormField<String>(
            value: [
              '高中毕业生',
              '在读大学生',
              '大四毕业生',
              '在读研究生',
              '在读博士生',
              '博士后',
              '其他'
            ].contains(tutorIdentity)
                ? tutorIdentity
                : null,
            items: [
              '高中毕业生',
              '在读大学生',
              '大四毕业生',
              '在读研究生',
              '在读博士生',
              '博士后',
              '其他'
            ]
                .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                .toList(),
            onChanged: (v) => setState(() => tutorIdentity = v),
            decoration: const InputDecoration(labelText: '对教员身份要求'),
          ),

          const SizedBox(height: 12),

          // 科目选择器：最多选 3 组
          SubjectSelector(
            key: _subjectKey,
            maxPairs: 3,
          ),

          const SizedBox(height: 12),

          // 报价区间
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

          // 上课时长 & 一周次数
          TextFormField(
            controller: durationController,
            maxLength: 3,
            decoration: const InputDecoration(labelText: '上课时长（小时）'),
          ),
          TextFormField(
            controller: frequencyController,
            maxLength: 3,
            decoration: const InputDecoration(labelText: '一周次数'),
          ),

          // 上课方式
          DropdownButtonFormField<String>(
            value: ['线上', '线下', '全部'].contains(teachMethod)
                ? teachMethod
                : null,
            items: ['线上', '线下', '全部']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => teachMethod = v),
            decoration: const InputDecoration(labelText: '上课方式'),
          ),

          // 授课地区（仅线下或全部时显示）
          if (teachMethod != '线上')
            TextFormField(
              controller: regionController,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '授课地区'),
            ),

          // 微信号
          TextFormField(
            controller: wechatController,
            maxLength: 20,
            decoration:
                const InputDecoration(labelText: '微信号（不对外展示）'),
          ),

          // 学员详细情况
          TextFormField(
            controller: descriptionController,
            maxLength: 100,
            minLines: 5,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '学员详细情况',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
