import 'package:flutter/material.dart';

/// Layout responsive del perfil público de academia.
class AcademyProfileLayout {
  AcademyProfileLayout._();

  static const double maxContentWidth = 920;
  static const double minTouchTarget = 44;

  static double heroExpandedHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1000) return 262;
    if (width >= 720) return 280;
    return 318;
  }

  static Widget constrainContent({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: padding != null
            ? Padding(padding: padding, child: child)
            : child,
      ),
    );
  }
}
