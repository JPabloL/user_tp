import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/award_score_format.dart';
import '../utils/match_helpers.dart';
import 'match_award_media.dart';
import 'match_award_tie_ui.dart';

enum MatchAwardType {
  featuredPlayer,
  offensiveLeader,
  defensiveLeader,
}

enum MatchAwardSpotlightVariant {
  hero,
  secondary,
}

/// Tarjeta spotlight editorial para reconocimientos calculados del partido.
class MatchAwardCard extends StatelessWidget {
  const MatchAwardCard({
    super.key,
    required this.awardType,
    required this.title,
    required this.subtitle,
    required this.player,
    required this.teamName,
    required this.teamLogoUrl,
    required this.teamColor,
    required this.score,
    required this.scoreLabel,
    required this.icon,
    this.supportingText = '',
    this.surfaceColor = const Color(0xFF1E293B),
    this.mutedTextColor = const Color(0xFF94A3B8),
    this.tiedPlayers = const [],
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
    this.onTap,
    this.width = 160,
    this.height = 224,
    this.showLeaderUpdated = false,
    this.variant = MatchAwardSpotlightVariant.secondary,
  });

  final MatchAwardType awardType;
  final String title;
  final String subtitle;
  final Map<String, dynamic> player;
  final String teamName;
  final String teamLogoUrl;
  final Color teamColor;
  final double score;
  final String scoreLabel;
  final IconData icon;
  final String supportingText;
  final Color surfaceColor;
  final Color mutedTextColor;
  final List<Map<String, dynamic>> tiedPlayers;
  final String Function(String) resolveMediaUrl;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final bool showLeaderUpdated;
  final MatchAwardSpotlightVariant variant;

  bool get _isHero => variant == MatchAwardSpotlightVariant.hero;

  static const double _minHeroHeight = 268;
  static const double _minSecondaryHeight = 210;

  String get _playerId =>
      (player['_id'] ?? player['id'] ?? '').toString().trim();

  bool get _hasTie => tiedPlayers.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final displayName = MatchHelpers.playerDisplayName(player);
    final number = MatchHelpers.formatPlayerNumber(player['number']);
    final teamLine = formatAwardTeamLine(number, teamName);
    final scoreText = formatAwardDisplayScore(score);
    final tiedLabel = matchAwardTiedPlayersLabel(tiedPlayers);
    final semanticsLabel = _buildSemanticsLabel(
      displayName: displayName,
      number: number,
      teamName: teamName,
      scoreText: scoreText,
    );

    final cardHeight = _isHero
        ? math.max(height, _minHeroHeight)
        : math.max(height, _minSecondaryHeight);
    final borderRadius = _isHero ? 16.0 : 14.0;

    final content = Semantics(
      container: true,
      button: onTap != null,
      label: semanticsLabel,
      hint: onTap != null ? 'Toca para ver el desglose' : null,
      child: SizedBox(
        width: width,
        height: cardHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: SizedBox(
                width: width,
                height: cardHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MatchAwardSpotlightBackdrop(
                      player: player,
                      teamColor: teamColor,
                      resolveMediaUrl: resolveMediaUrl,
                      imageAlignment: _isHero
                          ? Alignment.topCenter
                          : Alignment.center,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: teamColor.withValues(alpha: 0.32),
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
                        color: teamColor.withValues(alpha: 0.55),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 2,
                      child: ColoredBox(
                        color: teamColor.withValues(alpha: 0.35),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CustomPaint(
                        size: Size(_isHero ? 14 : 11, _isHero ? 14 : 11),
                        painter: _HudCornerPainter(
                          color: teamColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: _isHero ? 48 : 36,
                      child: CustomPaint(
                        size: Size(_isHero ? 56 : 42, 1),
                        painter: _HudLinePainter(
                          color: teamColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Positioned(
                      top: _isHero ? 14 : 10,
                      left: _isHero ? 14 : 11,
                      right: _isHero ? 14 : 11,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _AwardBadge(
                              title: title,
                              subtitle: subtitle,
                              icon: icon,
                              teamColor: teamColor,
                              isHero: _isHero,
                              mutedTextColor: mutedTextColor,
                            ),
                          ),
                          if (_hasTie) ...[
                            const SizedBox(width: 6),
                            const MatchAwardTieChip(),
                          ],
                          if (showLeaderUpdated) ...[
                            const SizedBox(width: 6),
                            _LeaderUpdatedChip(),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: _isHero ? 14 : 11,
                      right: _isHero ? 14 : 11,
                      bottom: _isHero ? 14 : 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              displayName,
                              key: ValueKey('name-$_playerId-$displayName'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.oswald(
                                color: Colors.white,
                                fontSize: _isHero ? 26 : 17,
                                fontWeight: FontWeight.w700,
                                height: 1.08,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: teamColor.withValues(alpha: 0.9),
                              fontSize: _isHero ? 10 : 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 0.92, end: 1)
                                          .animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  scoreText,
                                  key: ValueKey('score-$scoreText'),
                                  style: GoogleFonts.oswald(
                                    color: Colors.white,
                                    fontSize: _isHero ? 40 : 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    scoreLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: mutedTextColor,
                                      fontSize: _isHero ? 9 : 7,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.6,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (teamLine.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (teamLogoUrl.isNotEmpty) ...[
                                  MatchAwardTeamLogoChip(
                                    logoUrl: teamLogoUrl,
                                    teamColor: teamColor,
                                    size: _isHero ? 18 : 15,
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
                                      fontSize: _isHero ? 11 : 9,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (tiedLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              tiedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: _isHero ? 8 : 7,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ] else if (supportingText.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              supportingText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: _isHero ? 8 : 7,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_hasTie)
                      Positioned(
                        right: _isHero ? 12 : 10,
                        bottom: _isHero ? 72 : 58,
                        child: MatchAwardTiePhotoStack(
                          primaryPlayer: player,
                          tiedPlayers: tiedPlayers,
                          teamColor: teamColor,
                          mainSize: _isHero ? 34 : 28,
                          miniSize: _isHero ? 20 : 16,
                          resolveMediaUrl: resolveMediaUrl,
                          useSpotlightPhoto: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: content,
      ),
    );
  }

  String _buildSemanticsLabel({
    required String displayName,
    required String? number,
    required String teamName,
    required String scoreText,
  }) {
    final recognition = _semanticsRecognitionName();
    final parts = <String>[recognition];
    if (_hasTie) parts.add('reconocimiento compartido');
    if (displayName.isNotEmpty) parts.add(displayName);
    if (number != null) parts.add('número $number');
    if (teamName.trim().isNotEmpty) parts.add('de $teamName');
    parts.add('$scoreText ${scoreLabel.toLowerCase()}');
    if (onTap != null) parts.add('Toca para ver el desglose');
    return parts.join(', ');
  }

  String _semanticsRecognitionName() {
    switch (awardType) {
      case MatchAwardType.featuredPlayer:
        return 'Jugador destacado';
      case MatchAwardType.offensiveLeader:
        return 'Líder ofensivo';
      case MatchAwardType.defensiveLeader:
        return 'Líder defensivo';
    }
  }
}

class _AwardBadge extends StatelessWidget {
  const _AwardBadge({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.teamColor,
    required this.isHero,
    required this.mutedTextColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color teamColor;
  final bool isHero;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isHero ? 10 : 8,
        vertical: isHero ? 6 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: teamColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isHero ? 12 : 10,
            color: teamColor.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: isHero ? 9 : 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                if (isHero && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: mutedTextColor,
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderUpdatedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        'LÍDER ACTUALIZADO',
        style: GoogleFonts.inter(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.9),
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
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
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HudCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HudLinePainter extends CustomPainter {
  _HudLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant _HudLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
