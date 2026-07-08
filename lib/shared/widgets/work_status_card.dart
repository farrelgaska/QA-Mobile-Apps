import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'app_card.dart';

class WorkStatusCard extends StatelessWidget {
  final String workName;
  final String locationName;
  final String status;

  const WorkStatusCard({
    Key? key,
    required this.workName,
    required this.locationName,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDone = status.toLowerCase() == 'selesai';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workName,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.textSoft),
                          const SizedBox(width: 2),
                          Text(
                            locationName,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFE8F7F1) : const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isDone ? 'Selesai' : 'On Progress',
                    style: TextStyle(
                      color: isDone ? const Color(0xFF006B5A) : const Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
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
