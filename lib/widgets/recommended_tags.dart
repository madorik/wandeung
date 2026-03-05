import 'package:flutter/material.dart';

class RecommendedTags extends StatelessWidget {
  final List<String> currentTags;
  final ValueChanged<List<String>> onTagsChanged;

  const RecommendedTags({
    super.key,
    required this.currentTags,
    required this.onTagsChanged,
  });

  static const recommendedTags = [
    '#다이나믹',
    '#슬랩',
    '#발컨',
    '#힐훅',
    '#토훅',
    '#맨틀링',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: recommendedTags.map((tag) {
        final isSelected = currentTags.contains(tag);
        return GestureDetector(
          onTap: () {
            final updated = List<String>.from(currentTags);
            if (isSelected) {
              updated.remove(tag);
            } else {
              updated.add(tag);
            }
            onTagsChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected ? Colors.green.shade300 : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
