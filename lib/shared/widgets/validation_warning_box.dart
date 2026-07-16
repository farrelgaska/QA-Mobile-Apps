import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ValidationWarningBox extends StatelessWidget {
  final String message;

  const ValidationWarningBox({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rejectedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rejectedText, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, size: 14, color: AppColors.rejectedText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.rejectedText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
