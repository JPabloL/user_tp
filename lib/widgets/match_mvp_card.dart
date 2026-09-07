import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/match_helpers.dart';
import 'match_award_media.dart';

/// Tarjeta spotlight del MVP del partido (reconocimiento manual).
class MatchMvpCard extends StatelessWidget {
  const MatchMvpCard({
    super.key,
    required this.player,
    required this.teamName,
    required this.teamLogoUrl,
    required this.teamColor,
    this.source = 'manual',
    this.surfaceColor = const Color(0xFF1E293B),
    this.goldAccent = const Color(0xFFFFD700),
    this.mutedTextColor = const Color(0xFF94A3B8),
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
    this.onTap,
  });

  final Map<String, dynamic> player;
  final String teamName;
  final String teamLogoUrl;
  final Color teamColor;
  final String source;
  final Color surfaceColor;
  final Color goldAccent;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;
  final VoidCallback? onTap;

  static const double _cardHeight = 200;

  @override
  Widget build(BuildContext context) {
    final displayName = MatchHelpers.playerDisplayName(player);
    final number = MatchHelpers.formatPlayerNumber(player['number']);
    final teamLine = _formatTeamLine(number, teamName);
    final semanticsLabel = _buildSemanticsLabel(
      displayName: displayName,
      number: number,
      teamName: teamName,
    );

    final content = Semantics(
      container: true,
      label: semanticsLabel,
      child: SizedBox(
        width: double.infinity,
        height: _cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MatchAwardSpotlightBackdrop(
                player: player,
                teamColor: teamColor,
                resolveMediaUrl: resolveMediaUrl,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: goldAccent.withValues(alpha: 0.38),
                    width: 1,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(
                  color: teamColor.withValues(alpha: 0.6),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 2,
                child: ColoredBox(
                  color: goldAccent.withValues(alpha: 0.45),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: ColoredBox(
                  color: teamColor.withValues(alpha: 0.3),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(14, 14),
                  painter: _MvpHudCornerPainter(
                    color: goldAccent.withValues(alpha: 0.42),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220).withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: goldAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: goldAccent.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'MVP DEL PARTIDO',
                        style: GoogleFonts.inter(
                          color: goldAccent.withValues(alpha: 0.95),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MVP DEL PARTIDO',
                      style: GoogleFonts.inter(
                        color: goldAccent.withValues(alpha: 0.88),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (teamLine.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (teamLogoUrl.isNotEmpty) ...[
                            MatchAwardTeamLogoChip(
                              logoUrl: teamLogoUrl,
                              teamColor: teamColor,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              teamLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: goldAccent.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _officialLabel,
                          style: GoogleFonts.inter(
                            color: mutedTextColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }

  String get _officialLabel => source == 'manual'
      ? 'ELEGIDO OFICIALMENTE'
      : 'ELEGIDO OFICIALMENTE';

  String _formatTeamLine(String? number, String team) {
    final teamLabel = team.trim();
    if (number != null && teamLabel.isNotEmpty) {
      return '#$number · $teamLabel';
    }
    if (number != null) return '#$number';
    return teamLabel;
  }

  String _buildSemanticsLabel({
    required String displayName,
    required String? number,
    required String teamName,
  }) {
    final parts = <String>['MVP del partido'];
    if (displayName.isNotEmpty) parts.add(displayName);
    if (number != null) parts.add('número $number');
    if (teamName.trim().isNotEmpty) parts.add('de $teamName');
    parts.add('elegido oficialmente');
    return parts.join(', ');
  }
}

class _MvpHudCornerPainter extends CustomPainter {
  _MvpHudCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MvpHudCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
