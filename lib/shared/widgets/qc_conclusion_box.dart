import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'app_card.dart';

class QCConclusionBox extends StatelessWidget {
  final String conclusionState; // 'Belum Lengkap' | 'Diterima' | 'Ditolak'

  const QCConclusionBox({
    super.key,
    required this.conclusionState,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.inactiveBg;
    Color textColor = AppColors.inactiveText;
    IconData icon = Icons.info_outline;
    String text = 'Harap selesaikan semua isian wajib & foto dokumentasi.';

    if (conclusionState == 'Diterima') {
      bgColor = AppColors.approvedBg;
      textColor = AppColors.approvedText;
      icon = Icons.check_circle_outline;
      text = 'Lulus Inspeksi - Semua kriteria mutu teruji memenuhi standar.';
    } else if (conclusionState == 'Ditolak' || conclusionState == 'Pending') {
      bgColor = const Color(0xFFFFF4E5);
      textColor = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
      text = 'Pending - Terdapat parameter mutu yang menyimpang.';
    } else {
      bgColor = AppColors.inactiveBg;
      textColor = AppColors.inactiveText;
      icon = Icons.pending_outlined;
      text = 'Belum Lengkap - Harap selesaikan seluruh isian wajib & foto dokumentasi.';
    }

    return AppCard(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kesimpulan Mutu: $conclusionState',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
