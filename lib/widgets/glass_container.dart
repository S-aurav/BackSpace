import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_blur.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final List<Color>? borderGradientColors;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.25,
    this.color = Colors.white,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderGradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = borderRadius ?? BorderRadius.circular(20);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: defaultRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AdaptiveBlur(
        borderRadius: defaultRadius,
        sigma: blur,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: kIsWeb ? color.withValues(alpha: 0.95) : color.withValues(alpha: opacity),
            borderRadius: defaultRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: kIsWeb ? 0.15 : 0.35),
                  width: 1.5,
                ),
            gradient: kIsWeb
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: opacity + 0.15),
                      color.withValues(alpha: opacity * 0.5),
                    ],
                  ),
          ),
          child: child,
        ),
      ),
    );
  }
}
