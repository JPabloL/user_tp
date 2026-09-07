import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'academy_profile_layout.dart';

/// Skeleton inicial alineado con hero, KPIs y primeras secciones.
class AcademyProfileSkeleton extends StatefulWidget {
  const AcademyProfileSkeleton({
    super.key,
    required this.heroHeight,
  });

  final double heroHeight;

  @override
  State<AcademyProfileSkeleton> createState() => _AcademyProfileSkeletonState();
}

class _AcademyProfileSkeletonState extends State<AcademyProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = 0.28 + (_pulseController.value * 0.18);
        return AcademyProfileLayout.constrainContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: widget.heroHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: AppTheme.navySurface),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.navyPrimary.withValues(alpha: 0.15),
                            AppTheme.navyPrimary.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Column(
                          children: [
                            const SizedBox(height: 36),
                            _SkeletonBlock(
                              width: 100,
                              height: 100,
                              radius: 16,
                              opacity: pulse,
                            ),
                            const SizedBox(height: 14),
                            _SkeletonBlock(
                              width: 240,
                              height: 22,
                              radius: 8,
                              opacity: pulse,
                            ),
                            const SizedBox(height: 10),
                            _SkeletonBlock(
                              width: 200,
                              height: 14,
                              radius: 6,
                              opacity: pulse,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SkeletonBlock(
                                  width: 72,
                                  height: 32,
                                  radius: 4,
                                  opacity: pulse,
                                ),
                                const SizedBox(width: 24),
                                _SkeletonBlock(
                                  width: 72,
                                  height: 32,
                                  radius: 4,
                                  opacity: pulse,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 108,
                      radius: 16,
                      opacity: pulse,
                    ),
                    const SizedBox(height: 10),
                    _SkeletonBlock(
                      width: 140,
                      height: 12,
                      radius: 6,
                      opacity: pulse,
                    ),
                    const SizedBox(height: 24),
                    _SkeletonBlock(
                      width: 160,
                      height: 14,
                      radius: 6,
                      opacity: pulse,
                    ),
                    const SizedBox(height: 14),
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 96,
                      radius: 14,
                      opacity: pulse,
                    ),
                    const SizedBox(height: 10),
                    _SkeletonBlock(
                      width: double.infinity,
                      height: 96,
                      radius: 14,
                      opacity: pulse,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.opacity,
  });

  final double width;
  final double height;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
