import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.primary;
    Color textColor = Colors.white;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = AppColors.primary;
        textColor = Colors.white;
        break;
      case AppButtonVariant.secondary:
        bgColor = AppColors.backgroundSoft;
        textColor = AppColors.primary;
        break;
      case AppButtonVariant.danger:
        bgColor = AppColors.rejectedBg;
        textColor = AppColors.rejectedText;
        break;
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = AppColors.primary;
        break;
    }

    if (onPressed == null) {
      bgColor = AppColors.inactiveBg;
      textColor = AppColors.inactiveText;
    }

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: 48,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: isLoading ? null : onPressed,
        child: content,
      ),
    );
  }
}
