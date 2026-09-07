import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../utils/tournament_participants_helpers.dart';

class TournamentAcademyGridItem extends StatefulWidget {
  const TournamentAcademyGridItem({
    super.key,
    required this.academyId,
    required this.academyName,
    required this.academyLogo,
    required this.teamCount,
    required this.resolveMediaUrl,
    this.themeAccent = AppTheme.brandTeal,
    this.filterCategoryShortName,
    this.onTap,
  });

  final String academyId;
  final String academyName;
  final String academyLogo;
  final int teamCount;
  final String Function(String) resolveMediaUrl;
  final Color themeAccent;
  final String? filterCategoryShortName;
  final VoidCallback? onTap;

  @override
  State<TournamentAcademyGridItem> createState() =>
      _TournamentAcademyGridItemState();
}

class _TournamentAcademyGridItemState extends State<TournamentAcademyGridItem> {
  static const double _radius = 18;
  static const Color _surface = Color(0xFF151D2E);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.academyName.trim().isNotEmpty ? widget.academyName.trim() : 'Academia';
    final logoUrl = widget.resolveMediaUrl(widget.academyLogo);
    final initials = TournamentParticipantsHelpers.academyInitials(displayName);
    final badgeLabel =
        TournamentParticipantsHelpers.teamCountBadgeLabel(widget.teamCount);
    final semanticsLabel = TournamentParticipantsHelpers.participantsSemanticsLabel(
      academyName: displayName,
      teamCount: widget.teamCount,
      categoryShortName: widget.filterCategoryShortName,
    );
    final accent = widget.themeAccent;
    final hasLogo = logoUrl.isNotEmpty;
    final isInteractive = widget.onTap != null;

    return Semantics(
      label: semanticsLabel,
      button: isInteractive,
      child: isInteractive
          ? _InteractiveCardShell(
              onTap: widget.onTap!,
              pressed: _pressed,
              onPressedChange: _setPressed,
              child: _cardContent(
                displayName: displayName,
                logoUrl: logoUrl,
                initials: initials,
                badgeLabel: badgeLabel,
                accent: accent,
                hasLogo: hasLogo,
                pressed: _pressed,
              ),
            )
          : _cardContent(
              displayName: displayName,
              logoUrl: logoUrl,
              initials: initials,
              badgeLabel: badgeLabel,
              accent: accent,
              hasLogo: hasLogo,
              pressed: false,
            ),
    );
  }

  Widget _cardContent({
    required String displayName,
    required String logoUrl,
    required String initials,
    required String badgeLabel,
    required Color accent,
    required bool hasLogo,
    required bool pressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth;
        final textScaler = MediaQuery.textScalerOf(context);
        final nameSize = textScaler.scale(cellWidth >= 150 ? 13.0 : 11.5);
        final badgeFontSize = textScaler.scale(cellWidth >= 150 ? 8.5 : 8.0);
        final logoPadding = cellWidth >= 150 ? 12.0 : 10.0;
        final initialsSize = cellWidth >= 150 ? 42.0 : 34.0;
        final badgeHorizontalPadding = cellWidth < 130 ? 6.0 : 8.0;

        return Material(
          color: Colors.transparent,
          elevation: 0,
          borderRadius: BorderRadius.circular(_radius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: pressed
                    ? accent.withValues(alpha: 0.55)
                    : const Color(0xFF334155).withValues(alpha: 0.75),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface,
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.9,
                      colors: [
                        const Color(0xFF1C2840),
                        _surface,
                        const Color(0xFF0E1524),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      logoPadding,
                      logoPadding + 22,
                      logoPadding,
                      logoPadding + 40,
                    ),
                    child: hasLogo
                        ? CachedNetworkImage(
                            imageUrl: logoUrl,
                            fit: BoxFit.contain,
                            memCacheWidth: 320,
                            fadeInDuration: const Duration(milliseconds: 150),
                            fadeOutDuration: const Duration(milliseconds: 100),
                            placeholder: (_, _) => _InitialsHero(
                              initials: initials,
                              accent: accent,
                              fontSize: initialsSize,
                            ),
                            errorWidget: (_, _, _) => _InitialsHero(
                              initials: initials,
                              accent: accent,
                              fontSize: initialsSize,
                            ),
                          )
                        : _InitialsHero(
                            initials: initials,
                            accent: accent,
                            fontSize: initialsSize,
                          ),
                  ),
                ),
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.88),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _HudCornerAccent(color: accent),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _TeamCountBadge(
                    label: badgeLabel,
                    accent: accent,
                    fontSize: badgeFontSize,
                    horizontalPadding: badgeHorizontalPadding,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: 0.35,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 28,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.15),
                          accent.withValues(alpha: 0.85),
                          accent.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveCardShell extends StatelessWidget {
  const _InteractiveCardShell({
    required this.onTap,
    required this.pressed,
    required this.onPressedChange,
    required this.child,
  });

  final VoidCallback onTap;
  final bool pressed;
  final ValueChanged<bool> onPressedChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressedChange(true),
      onTapUp: (_) => onPressedChange(false),
      onTapCancel: () => onPressedChange(false),
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _TeamCountBadge extends StatelessWidget {
  const _TeamCountBadge({
    required this.label,
    required this.accent,
    required this.fontSize,
    this.horizontalPadding = 8,
  });

  final String label;
  final Color accent;
  final double fontSize;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _HudCornerAccent extends StatelessWidget {
  const _HudCornerAccent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _HudCornerPainter(color: color.withValues(alpha: 0.85)),
      ),
    );
  }
}

class _HudCornerPainter extends CustomPainter {
  _HudCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.35)
      ..lineTo(0, 0)
      ..lineTo(size.width * 0.35, 0);

    canvas.drawPath(path, paint);

    final diamond = Path()
      ..moveTo(size.width * 0.55, size.height * 0.55)
      ..lineTo(size.width * 0.65, size.height * 0.45)
      ..lineTo(size.width * 0.75, size.height * 0.55)
      ..lineTo(size.width * 0.65, size.height * 0.65)
      ..close();

    canvas.drawPath(
      diamond,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _HudCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _InitialsHero extends StatelessWidget {
  const _InitialsHero({
    required this.initials,
    required this.accent,
    required this.fontSize,
  });

  final String initials;
  final Color accent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.12),
                Colors.transparent,
              ],
              radius: 0.75,
            ),
          ),
        ),
        Text(
          initials,
          style: GoogleFonts.oswald(
            color: accent.withValues(alpha: 0.92),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
