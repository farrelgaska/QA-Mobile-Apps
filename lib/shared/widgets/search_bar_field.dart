import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SearchBarField extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;

  const SearchBarField({
    super.key,
    required this.placeholder,
    this.onChanged,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF006B5A),
              decoration: InputDecoration(
                hintText: placeholder,
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
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
