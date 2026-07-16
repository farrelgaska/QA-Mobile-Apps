import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/enums.dart';
import 'app_card.dart';
import 'status_badge.dart';

class ReportCard extends StatelessWidget {
  final String reportId;
  final String title;
  final DateTime date;
  final String location;
  final dynamic status;
  final QCType type;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.reportId,
    required this.title,
    required this.date,
    required this.location,
    required this.status,
    required this.type,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(date);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: type == QCType.material ? AppColors.primarySoft : AppColors.infoBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type == QCType.material ? 'MATERIAL' : 'PEKERJAAN',
                    style: TextStyle(
                      color: type == QCType.material ? AppColors.primary : AppColors.infoText,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reportId,
              style: const TextStyle(
                color: AppColors.textSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSoft, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSoft),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSoft),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
