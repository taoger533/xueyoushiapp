import 'package:flutter/material.dart';

class TeacherFilterBar extends StatelessWidget {
  final String selectedPhase;
  final String selectedSubject;
  final String selectedGender;
  final List<String> phases;
  final List<String> subjects;
  final List<String> genders;
  final ValueChanged<String?> onPhaseChanged;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onGenderChanged;

  const TeacherFilterBar({
    super.key,
    required this.selectedPhase,
    required this.selectedSubject,
    required this.selectedGender,
    required this.phases,
    required this.subjects,
    required this.genders,
    required this.onPhaseChanged,
    required this.onSubjectChanged,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          DropdownButton<String>(
            value: selectedPhase,
            items: phases
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    ))
                .toList(),
            onChanged: onPhaseChanged,
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: selectedSubject,
            items: subjects
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s),
                    ))
                .toList(),
            onChanged: onSubjectChanged,
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: selectedGender,
            items: genders
                .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g),
                    ))
                .toList(),
            onChanged: onGenderChanged,
          ),
        ],
      ),
    );
  }
}
