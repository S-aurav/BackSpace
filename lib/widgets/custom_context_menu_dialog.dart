import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../helper/theme_controller.dart';

class ContextMenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  ContextMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

class CustomContextMenuDialog extends StatelessWidget {
  final String? title;
  final Widget? headerWidget;
  final List<ContextMenuItem> items;
  final Offset? targetOffset;

  const CustomContextMenuDialog({
    super.key,
    this.title,
    this.headerWidget,
    required this.items,
    this.targetOffset,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? headerWidget,
    required List<ContextMenuItem> items,
    Offset? targetOffset,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return CustomContextMenuDialog(
          title: title,
          headerWidget: headerWidget,
          items: items,
          targetOffset: targetOffset,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18 * anim1.value,
            sigmaY: 18 * anim1.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnim),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;
    final screenSize = MediaQuery.of(context).size;

    final Widget menuBox = Container(
      width: 265,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2E).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (headerWidget != null) ...[
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: headerWidget!,
              ),
              Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
            ] else if (title != null && title!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  title!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ThemeController.subtextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
            ],

            ...List.generate(items.length, (index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      item.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: item.isDestructive
                                  ? Colors.redAccent
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          Icon(
                            item.icon,
                            size: 19,
                            color: item.isDestructive
                                ? Colors.redAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                ],
              );
            }),
          ],
        ),
      ),
    );

    final Widget interactiveMenuBox = GestureDetector(
      onTap: () {}, // Absorb taps on the popover card itself
      child: menuBox,
    );

    if (targetOffset != null) {
      final topPadding = MediaQuery.of(context).padding.top + 40;
      final bottomPadding = MediaQuery.of(context).padding.bottom + 40;
      final estimatedHeight = (items.length * 46) + 40;

      double top = targetOffset!.dy - (estimatedHeight / 2);
      if (top < topPadding) top = topPadding;
      if (top + estimatedHeight > screenSize.height - bottomPadding) {
        top = screenSize.height - bottomPadding - estimatedHeight;
      }

      double left = targetOffset!.dx - 132.5;
      if (left < 16) left = 16;
      if (left + 265 > screenSize.width - 16) left = screenSize.width - 265 - 16;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                top: top,
                left: left,
                child: interactiveMenuBox,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: interactiveMenuBox,
          ),
        ),
      ),
    );
  }
}
