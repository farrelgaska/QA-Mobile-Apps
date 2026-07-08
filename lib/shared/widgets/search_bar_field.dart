import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SearchBarField extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;

  const SearchBarField({
    Key? key,
    required this.placeholder,
    this.onChanged,
    this.onFilterTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.textMain, fontSize: 14),
              decoration: InputDecoration(
                hintText: placeholder,
                prefixIcon: const Icon(Icons.search, color: AppColors.textSoft, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.tune,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
