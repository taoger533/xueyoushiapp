import 'package:flutter/material.dart';

class TeacherCard extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final bool isBooked;
  final VoidCallback onBook;
  final VoidCallback onTap;

  const TeacherCard({
    super.key,
    required this.teacher,
    required this.isBooked,
    required this.onBook,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subjectList = (teacher['subjects'] as List)
        .map((s) => '${s['phase']} ${s['subject']}')
        .join('，');
    final accepting = teacher['acceptingStudents'] as bool? ?? false;
    final List<String> titles =
        (teacher['titles'] as List?)?.cast<String>() ?? [];
    final List<Widget> chipWidgets = [];
    for (final tt in titles) {
      chipWidgets.add(
        Chip(
          label: Text(tt, style: const TextStyle(fontSize: 12)),
        ),
      );
    }
    return Stack(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text('教员：${teacher['name']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chipWidgets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: chipWidgets,
                    ),
                  ),
                Text('性别：${teacher['gender']}'),
                Text('身份：${teacher['identity']}'),
                Text('毕业院校：${teacher['school']}'),
                Text('专业：${teacher['major']}'),
                Text('教学经验：${teacher['exp']}'),
                Text(
                    '报价范围：${teacher['rateMin']}-${teacher['rateMax']}'),
                Text('授课科目：$subjectList'),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: isBooked ? null : onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: isBooked ? Colors.grey : null,
              ),
              child: Text(isBooked ? '已预约' : '预约'),
            ),
            onTap: onTap,
          ),
        ),
        if (!accepting)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: const Text(
                '已有学生，暂停接收',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}
