import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Performance-optimized Adaptive Blur Widget.
/// - On Native Mobile (Android & iOS): Renders authentic GPU-accelerated [BackdropFilter].
/// - On Web (PWA / Browser): Bypasses [BackdropFilter] completely to eliminate heavy multi-pass
///   framebuffer readbacks and Gaussian blur shaders that cause lag and low frame rates.
class AdaptiveBlur extends StatelessWidget {
  final double sigma;
  final double? sigmaX;
  final double? sigmaY;
  final Widget child;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  const AdaptiveBlur({
    super.key,
    this.sigma = 25.0,
    this.sigmaX,
    this.sigmaY,
    required this.child,
    this.borderRadius,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (borderRadius != null) {
        return ClipRRect(
          borderRadius: borderRadius!,
          clipBehavior: clipBehavior,
          child: child,
        );
      }
      return ClipRect(
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    final double effectiveSigmaX = sigmaX ?? sigma;
    final double effectiveSigmaY = sigmaY ?? sigma;

    final filter = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: effectiveSigmaX, sigmaY: effectiveSigmaY),
      child: child,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        clipBehavior: clipBehavior,
        child: filter,
      );
    }

    return ClipRect(
      clipBehavior: clipBehavior,
      child: filter,
    );
  }
}
