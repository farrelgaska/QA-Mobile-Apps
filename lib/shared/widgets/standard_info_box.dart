import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StandardInfoBox extends StatelessWidget {
  final String standardText;
  final String? validRangeText;
  final String? unit;

  const StandardInfoBox({
    Key? key,
    required this.standardText,
    this.validRangeText,
    this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2.0),
                child: Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Standar: $standardText',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (validRangeText != null && validRangeText!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 18.0),
              child: Text(
                'Range Valid: $validRangeText',
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
