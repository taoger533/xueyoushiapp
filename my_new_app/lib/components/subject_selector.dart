// subject_selector.dart
import 'package:flutter/material.dart';

/// A reusable widget for selecting multiple teaching subject-phase pairs.
/// Extracted from TeacherProfileForm for modularity.
class SubjectSelector extends StatefulWidget {
  /// Initial list of subject-phase pairs.
  final List<Map<String, String>> initialSubjectPairs;

  /// Maximum number of pairs allowed.
  final int maxPairs;

  const SubjectSelector({
    Key? key,
    this.initialSubjectPairs = const [],
    this.maxPairs = 10,
  }) : super(key: key);

  @override
  SubjectSelectorState createState() => SubjectSelectorState();
}

class SubjectSelectorState extends State<SubjectSelector> {
  // Phase options
  final List<String> phaseOptions = [
    '小学',
    '小初衔接',
    '初一',
    '初二',
    '初三',
    '初高衔接',
    '高中',
    '高三',
    '大学',
    '英语',
    '其他',
  ];

  // Mapping from phase to available subjects
  final Map<String, List<String>> subjectOptionsMap = {
    '小学': ['语文', '数学', '英语'],
    '小初衔接': ['语文', '数学', '英语'],
    '初一': ['语文', '数学', '英语'],
    '初二': ['语文', '数学', '英语', '物理', '生物', '地理', '历史', '政治'],
    '初三': ['语文', '数学', '英语', '物理', '化学', '生物', '地理', '历史', '政治'],
    '初高衔接': ['语文', '数学', '英语', '物理', '化学', '生物', '地理', '历史', '政治'],
    '高中': ['语文', '数学', '英语', '物理', '化学', '生物', '地理', '历史', '政治'],
    '高三': ['语文', '数学', '英语', '物理', '化学', '生物', '地理', '历史', '政治'],
    '大学': ['高等数学', '普通物理', '计算机', '其他'],
    '英语': ['英语四级', '英语六级', '雅思', '托福'],
    '其他': [],
  };

  // Currently selected subject-phase pairs
  late List<Map<String, String>> subjectPairs;

  @override
  void initState() {
    super.initState();
    // Initialize with any existing selections
    subjectPairs = List<Map<String, String>>.from(widget.initialSubjectPairs);
  }

  /// Adds a new pair with default values
  void addSubjectPair() {
    if (subjectPairs.length >= widget.maxPairs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能添加 ${widget.maxPairs} 组授课科目')),
      );
      return;
    }
    setState(() {
      final defaultPhase = phaseOptions.first;
      subjectPairs.add({
        'phase': defaultPhase,
        'subject': subjectOptionsMap[defaultPhase]!.isNotEmpty
            ? subjectOptionsMap[defaultPhase]!.first
            : '',
      });
    });
  }

  /// Removes the pair at the given index
  void removeSubjectPair(int index) {
    setState(() {
      subjectPairs.removeAt(index);
    });
  }

  /// Exposes the current list of selections
  List<Map<String, String>> getSubjectPairs() => subjectPairs;

  /// Allows updating selections from outside (e.g., restoring saved data)
  void setSubjectPairs(List<Map<String, String>> pairs) {
    setState(() {
      subjectPairs = List<Map<String, String>>.from(pairs);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool reachedMax = subjectPairs.length >= widget.maxPairs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '授课科目（已选 ${subjectPairs.length}/${widget.maxPairs} 组）',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Render each pair
        ...subjectPairs.asMap().entries.map((entry) {
          final index = entry.key;
          final pair = entry.value;
          final phase = pair['phase'] ?? phaseOptions.first;
          final subjectList = subjectOptionsMap[phase] ?? [];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Phase dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: phaseOptions.contains(phase) ? phase : null,
                    items: phaseOptions
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (newPhase) {
                      if (newPhase == null) return;
                      setState(() {
                        subjectPairs[index]['phase'] = newPhase;
                        subjectPairs[index]['subject'] =
                            subjectOptionsMap[newPhase]!.isNotEmpty
                                ? subjectOptionsMap[newPhase]!.first
                                : '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Subject selector or free input if '其他'
                Expanded(
                  flex: 2,
                  child: phase == '其他'
                      ? TextFormField(
                          initialValue: pair['subject'],
                          maxLength: 10,
                          decoration:
                              const InputDecoration(labelText: '请输入科目'),
                          onChanged: (val) {
                            setState(() {
                              subjectPairs[index]['subject'] = val;
                            });
                          },
                        )
                      : DropdownButtonFormField<String>(
                          value: subjectList.contains(pair['subject'])
                              ? pair['subject']
                              : null,
                          items: subjectList
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (newSubject) {
                            if (newSubject == null) return;
                            setState(() {
                              subjectPairs[index]['subject'] = newSubject;
                            });
                          },
                        ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => removeSubjectPair(index),
                ),
              ],
            ),
          );
        }).toList(),
        // Add button
        TextButton.icon(
          icon: Icon(Icons.add, color: reachedMax ? Colors.grey : null),
          label: Text(
            '添加授课科目',
            style: TextStyle(color: reachedMax ? Colors.grey : null),
          ),
          onPressed: reachedMax ? null : addSubjectPair,
        ),
      ],
    );
  }
}