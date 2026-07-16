import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PhotoUploadBox extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const PhotoUploadBox({
    super.key,
    required this.onTap,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.backgroundSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textSoft.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            SizedBox(height: 4),
            Text(
              'Tambah Foto',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
