import 'package:flutter/material.dart';

class TeacherDetailPage extends StatelessWidget {
  final Map<String, dynamic> teacher;
  const TeacherDetailPage({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    // 格式化授课科目
    final subjectList = (teacher['subjects'] as List<dynamic>)
        .map((s) => '${s['phase']} ${s['subject']}')
        .join('，');

    return Scaffold(
      appBar: AppBar(title: Text('教员详情：${teacher['name']}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRow('姓名', teacher['name']),
            _buildRow('性别', teacher['gender']),
            _buildRow('身份', teacher['identity']),
            _buildRow('毕业院校', teacher['school']),
            _buildRow('专业', teacher['major']),
            _buildRow('教学经验', teacher['exp']),
            _buildRow('报价范围',
                '${teacher['rateMin']}-${teacher['rateMax']}'),
            _buildRow('授课科目', subjectList),
            // 教员详细情况：调用后端 remark 字段
            _buildRow('教员详细情况', teacher['description'] ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child:
                Text('$label：', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
