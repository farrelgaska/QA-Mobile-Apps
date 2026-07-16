import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/screen_header.dart';

class QCPekerjaanSegmentScreen extends StatelessWidget {
  const QCPekerjaanSegmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(
                title: 'QC Pekerjaan',
                subtitle: 'Pilih segmentasi pekerjaan untuk dilakukan Quality Control',
              ),
              const SizedBox(height: 12),
              
              _buildSegmentCard(
                context: context,
                title: 'Provisioning',
                description: 'Inspeksi pemasangan ONT, penarikan kabel dropcore, & aktivasi pelanggan.',
                icon: Icons.settings_input_component,
                segmentName: 'provisioning',
                color: AppColors.infoBg,
                iconColor: AppColors.infoText,
              ),
              const SizedBox(height: 16),
              _buildSegmentCard(
                context: context,
                title: 'Assurance',
                description: 'Inspeksi kualitas redaman fiber optic, pemeliharaan, & kebersihan ODP.',
                icon: Icons.speed_outlined,
                segmentName: 'assurance',
                color: AppColors.primarySoft,
                iconColor: AppColors.primary,
              ),
              const SizedBox(height: 16),
              _buildSegmentCard(
                context: context,
                title: 'Construction',
                description: 'Pekerjaan konstruksi tiang, pengecoran pondasi, & penarikan kabel feeder.',
                icon: Icons.home_repair_service_outlined,
                segmentName: 'construction',
                color: AppColors.revisionBg,
                iconColor: AppColors.revisionText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required String segmentName,
    required Color color,
    required Color iconColor,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      onTap: () {
        context.push('/qc-pekerjaan/list/$segmentName');
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.arrow_forward_ios, color: AppColors.textSoft, size: 16),
          ),
        ],
      ),
    );
  }
}
