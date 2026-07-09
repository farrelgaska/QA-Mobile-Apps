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
    final lowerStatus = status.toLowerCase().trim();
    Color bgColor;
    Color textColor;
    String displayStatus = status;

    if (lowerStatus == 'selesai' || lowerStatus == 'disetujui' || lowerStatus == 'lulus') {
      bgColor = AppColors.approvedBg;
      textColor = AppColors.approvedText;
      displayStatus = 'Selesai';
    } else if (lowerStatus == 'perlu perbaikan' || lowerStatus == 'tidak sesuai') {
      bgColor = AppColors.rejectedBg;
      textColor = AppColors.rejectedText;
      displayStatus = 'Perlu Perbaikan';
    } else {
      bgColor = AppColors.waitingBg;
      textColor = AppColors.waitingText;
      displayStatus = 'On Progress';
    }
    
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
                    color: bgColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      color: textColor,
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
