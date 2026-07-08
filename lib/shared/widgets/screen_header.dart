import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final List<Widget>? actions;

  const ScreenHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBackButton) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textMain, size: 20),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            if (actions != null) ...actions!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
