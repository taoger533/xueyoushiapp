import 'package:flutter/material.dart';

/// 内置筛选数据
class _FilterData {
  // 学段
  static const List<String> phases = [
    '不限', '小学', '初中', '高中', '大学', '成人',
  ];

  // 科目（含你截图里的全部）
  static const List<String> subjects = [
    '不限',
    '数学','英语','语文','物理','化学',
    '生物','地理','历史','政治','作文',
    '奥数','钢琴','电子琴','古筝','竹笛',
    '美术','日语','德语','法语','韩语',
    '俄语','雅思','托福','计算机','英语口语',
  ];

  // 性别
  static const List<String> genders = ['不限', '男', '女'];
}

/// 顶部筛选条：下拉筛选 + 网格快捷科目
/// - selectedPhase / selectedSubject / selectedGender 由父级管理（可为 null）
/// - onPhaseChanged / onSubjectChanged / onGenderChanged 回调沿用你现有逻辑
class TeacherFilterBar extends StatelessWidget {
  final String? selectedPhase;
  final String? selectedSubject;
  final String? selectedGender;
  final ValueChanged<String?> onPhaseChanged;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onGenderChanged;

  /// 是否显示下面的“科目快捷网格”
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部三项：学段 / 科目 / 性别
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: selectedPhase,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '学段'),
                  items: _buildNullableItems(_FilterData.phases),
                  onChanged: onPhaseChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: selectedSubject,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '科目'),
                  items: _buildNullableItems(_FilterData.subjects),
                  onChanged: onSubjectChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: selectedGender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '性别'),
                  items: _buildNullableItems(_FilterData.genders),
                  onChanged: onGenderChanged,
                ),
              ),
            ],
          ),
        ),

        // 快捷科目网格（点击即可快速触发科目筛选，风格贴近你的截图）
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
                      final cross =
                          c.maxWidth >= 560 ? 5 : (c.maxWidth >= 420 ? 4 : 3);
                      final subjects = _FilterData.subjects.where((s) => s != '不限').toList();
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subjects.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        itemBuilder: (_, i) {
                          final s = subjects[i];
                          final isSelected = selectedSubject == s;
                          return OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
                              side: BorderSide(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => onSubjectChanged(s),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 15,
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
                      onPressed: () => onSubjectChanged(null), // 清空科目
                      icon: const Icon(Icons.refresh),
                      label: const Text('清空科目'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 把 "不限" 作为可选项之一；支持传 null 表示“未选择/清空”
  static List<DropdownMenuItem<String?>> _buildNullableItems(
      List<String> options) {
    // 用 null 代表“不限/全部”，下拉里显示成“全部”
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('全部'),
      ),
    ];
    items.addAll(
      options.map((e) => DropdownMenuItem<String?>(
            value: e == '不限' ? null : e,
            child: Text(e == '不限' ? '全部' : e),
          )),
    );
    return items;
  }
}
