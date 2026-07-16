import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A shimmer / skeleton loading placeholder widget.
/// Usage: Wrap your list or grid with ShimmerPlaceholder to show
/// placeholder cards while data is loading.
class ShimmerPlaceholder extends StatefulWidget {
  /// Number of skeleton rows to show
  final int itemCount;

  /// Whether to show a card-style skeleton (default) or a list-tile style
  final ShimmerStyle style;

  const ShimmerPlaceholder({
    super.key,
    this.itemCount = 3,
    this.style = ShimmerStyle.card,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.itemCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.style == ShimmerStyle.card
                  ? _buildCardSkeleton()
                  : _buildListTileSkeleton(),
            );
          }),
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildShimmerBox(width: 80, height: 12),
              _buildShimmerBox(width: 60, height: 20, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 12),
          _buildShimmerBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          _buildShimmerBox(width: 180, height: 12),
          const SizedBox(height: 8),
          _buildShimmerBox(width: 120, height: 12),
        ],
      ),
    );
  }

  Widget _buildListTileSkeleton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildShimmerBox(width: 40, height: 40, borderRadius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: double.infinity, height: 12),
                const SizedBox(height: 6),
                _buildShimmerBox(width: 100, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum ShimmerStyle { card, listTile }
