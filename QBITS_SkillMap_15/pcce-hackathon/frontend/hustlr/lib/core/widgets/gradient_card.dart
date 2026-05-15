import 'package:flutter/material.dart';
import 'package:hustlr/core/theme/app_colors.dart';

/// A gradient card container used as a section header or hero card
class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient = AppColors.primaryGradient,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
