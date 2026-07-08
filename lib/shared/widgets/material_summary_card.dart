import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'app_card.dart';

class MaterialSummaryCard extends StatelessWidget {
  final String materialName;
  final String status;
  final String sampleCount;

  const MaterialSummaryCard({
    Key? key,
    required this.materialName,
    required this.status,
    required this.sampleCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPassed = status.toLowerCase() == 'lulus' || status.toLowerCase() == 'disetujui';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    materialName,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.approvedBg : AppColors.rejectedBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isPassed ? AppColors.approvedText : AppColors.rejectedText,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 14, color: AppColors.textSoft),
                const SizedBox(width: 6),
                Text(
                  'Jumlah Sampel: $sampleCount',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
