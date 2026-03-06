import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DifficultySelector extends StatelessWidget {
  final DifficultyColor? selectedColor;
  final ValueChanged<DifficultyColor> onColorChanged;

  const DifficultySelector({
    super.key,
    this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('난이도 색상',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colorScheme.onSurface,
            )),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: DifficultyColor.values.map((dc) {
            final isSelected = dc == selectedColor;
            final baseColor = Color(dc.colorValue);
            return GestureDetector(
              onTap: () => onColorChanged(dc),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.black.withOpacity(0.08),
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: baseColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check_rounded,
                            color: dc == DifficultyColor.white ||
                                    dc == DifficultyColor.yellow
                                ? Colors.black87
                                : Colors.white,
                            size: 20)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dc.korean,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
