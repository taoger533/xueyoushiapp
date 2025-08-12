import 'package:flutter/material.dart';

class TeacherFilterBar extends StatelessWidget {
  final List<String> phases;
  final List<String> subjects;
  final List<String> genders;
  final String? selectedPhase;
  final String? selectedSubject;
  final String? selectedGender;
  final ValueChanged<String?> onPhaseChanged;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onGenderChanged;

  const TeacherFilterBar({
    super.key,
    required this.phases,
    required this.subjects,
    required this.genders,
    required this.selectedPhase,
    required this.selectedSubject,
    required this.selectedGender,
    required this.onPhaseChanged,
    required this.onSubjectChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedPhase,
              decoration: const InputDecoration(labelText: '学段'),
              items: phases
                  .map((e) => DropdownMenuItem(
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
              value: selectedSubject,
              decoration: const InputDecoration(labelText: '科目'),
              items: subjects
                  .map((e) => DropdownMenuItem(
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
              value: selectedGender,
              decoration: const InputDecoration(labelText: '性别'),
              items: genders
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: onGenderChanged,
            ),
          ),
        ],
      ),
    );
  }
}
