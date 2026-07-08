import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'app_button.dart';

class ConfirmationModal extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final bool isDanger;

  const ConfirmationModal({
    Key? key,
    required this.title,
    required this.message,
    this.confirmText = 'Ya, Lanjutkan',
    this.cancelText = 'Batal',
    required this.onConfirm,
    this.isDanger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: cancelText,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  text: confirmText,
                  variant: isDanger ? AppButtonVariant.danger : AppButtonVariant.primary,
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
