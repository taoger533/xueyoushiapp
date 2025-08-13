import 'package:flutter/material.dart';

/// 顶部筛选条：下拉筛选 + 可选的科目快捷网格
/// 统一规则：用字符串“全部”表示不限；绝不使用 null。
class TeacherFilterBar extends StatelessWidget {
  // 选中值（务必传“全部”或具体值）
  final String selectedPhase;
  final String selectedSubject;
  final String selectedGender;

  // 变更回调（会把“全部”或具体值原样回传）
  final ValueChanged<String?> onPhaseChanged;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onGenderChanged;

  // 是否展示下面的科目快捷网格
  final bool showQuickSubjects;

  const TeacherFilterBar({
    super.key,
    required this.selectedPhase,
    required this.selectedSubject,
    required this.selectedGender,
    required this.onPhaseChanged,
    required this.onSubjectChanged,
    required this.onGenderChanged,
    this.showQuickSubjects = true,
  });

  // 内置选项 —— 全部都是 String，且包含“全部”
  static const List<String> _phases = [
    '全部', '小学', '初中', '高中', '大学', '成人',
  ];

  static const List<String> _subjects = [
    '全部',
    '数学','英语','语文','物理','化学',
    '生物','地理','历史','政治','作文',
    '奥数','钢琴','电子琴','古筝','竹笛',
    '美术','日语','德语','法语','韩语',
    '俄语','雅思','托福','计算机','英语口语',
  ];

  static const List<String> _genders = ['全部', '男', '女'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 三个下拉
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _ensureInList(selectedPhase, _phases),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '学段'),
                  items: _phases
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: onPhaseChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _ensureInList(selectedSubject, _subjects),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '科目'),
                  items: _subjects
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: onSubjectChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _ensureInList(selectedGender, _genders),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '性别'),
                  items: _genders
                      .map((e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(e),
                          ))
                      .toList(),
                  onChanged: onGenderChanged,
                ),
              ),
            ],
          ),
        ),

        // 科目快捷网格（不含“全部”）
        if (showQuickSubjects)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('按科目快速筛选',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, c) {
                      final quick = _subjects.where((s) => s != '全部').toList();
                      final cross = c.maxWidth >= 560 ? 5 : 4;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: quick.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        itemBuilder: (_, i) {
                          final s = quick[i];
                          final isSelected = selectedSubject == s;
                          return OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                              ),
                              backgroundColor: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08)
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => onSubjectChanged(s),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onSubjectChanged('全部'),
                      icon: const Icon(Icons.refresh),
                      label: const Text('清空科目（全部）'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 兜底：如果传入值不在列表里，强制回退为“全部”，避免 Dropdown 断言报错
  static String _ensureInList(String value, List<String> options) {
    return options.contains(value) ? value : '全部';
  }
}
