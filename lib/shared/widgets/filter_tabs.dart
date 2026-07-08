import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FilterTabs extends StatelessWidget {
  final List<String> items;
  final String selectedItem;
  final ValueChanged<String> onSelected;

  const FilterTabs({
    Key? key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: items.map((item) {
          final isSelected = item == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => onSelected(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.backgroundSoft,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
