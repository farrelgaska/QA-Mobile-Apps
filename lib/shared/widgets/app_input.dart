import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppInput extends StatelessWidget {
  final String label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool isObscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const AppInput({
    Key? key,
    required this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.isObscure = false,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textMain, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.textSoft, size: 20) : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
