import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/match_helpers.dart';

/// Sección "Mención especial" para jugadores gestionados o seguidos en el partido.
class MatchSpecialMentionSection extends StatelessWidget {
  const MatchSpecialMentionSection({
    super.key,
    required this.players,
    required this.gameStatsByPlayerId,
    required this.homeTeamName,
    required this.visitorTeamName,
    required this.homeColor,
    required this.visitColor,
    required this.mutedTextColor,
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
  });

  final List<Map<String, dynamic>> players;
  final Map<String, Map<String, dynamic>> gameStatsByPlayerId;
  final String homeTeamName;
  final String visitorTeamName;
  final Color homeColor;
  final Color visitColor;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_rounded, color: homeColor, size: 18),
            const SizedBox(width: 8),
            Text(
              'TÚ JUGADOR',
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (players.length == 1)
          _SpecialMentionCard(
            player: players.first,
            stats: gameStatsByPlayerId[
                MatchHelpers.relatedPlayerId(players.first)],
            teamName: _teamName(players.first),
            teamColor: _teamColor(players.first),
            visitColor: visitColor,
            mutedTextColor: mutedTextColor,
            resolveMediaUrl: resolveMediaUrl,
            expanded: true,
          )
        else
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final player = players[index];
                final id = MatchHelpers.relatedPlayerId(player);
                return _SpecialMentionCard(
                  player: player,
                  stats: gameStatsByPlayerId[id],
                  teamName: _teamName(player),
                  teamColor: _teamColor(player),
                  visitColor: visitColor,
                  mutedTextColor: mutedTextColor,
                  resolveMediaUrl: resolveMediaUrl,
                );
              },
            ),
          ),
      ],
    );
  }

  String _teamName(Map<String, dynamic> player) {
    return player['isHome'] == true ? homeTeamName : visitorTeamName;
  }

  Color _teamColor(Map<String, dynamic> player) {
    return player['isHome'] == true ? homeColor : visitColor;
  }
}

class _SpecialMentionCard extends StatelessWidget {
  const _SpecialMentionCard({
    required this.player,
    required this.stats,
    required this.teamName,
    required this.teamColor,
    required this.visitColor,
    required this.mutedTextColor,
    required this.resolveMediaUrl,
    this.expanded = false,
  });

  final Map<String, dynamic> player;
  final Map<String, dynamic>? stats;
  final String teamName;
  final Color teamColor;
  final Color visitColor;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final displayName = MatchHelpers.playerDisplayName(player);
    final number = MatchHelpers.formatPlayerNumber(player['number']);
    final photoUrl = MatchHelpers.playerSpotlightPhotoUrl(player);
    final initials = MatchHelpers.playerInitials(player);
    final isFollowed = player['relation']?.toString() == 'followed';
    final hasStats = MatchHelpers.playerHasGameStats(stats);
    final statsSummary = hasStats
        ? MatchHelpers.playerGameStatsSummary(stats!)
        : '';
    final positions = MatchHelpers.playerPositionsLabel(player, fallback: '');

    final width = expanded
        ? MediaQuery.sizeOf(context).width - 32
        : 168.0;
    const height = 196.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: teamColor.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoUrl.isNotEmpty)
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => _fallbackBg(teamColor, initials),
            )
          else
            _fallbackBg(teamColor, initials),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  teamColor.withValues(alpha: 0.06),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: teamColor.withValues(alpha: 0.65)),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isFollowed
                      ? visitColor.withValues(alpha: 0.45)
                      : teamColor.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                isFollowed ? 'SEGUIDO' : 'GESTIONADO',
                style: GoogleFonts.inter(
                  color: isFollowed ? visitColor : teamColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
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
                    fontSize: expanded ? 22 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                  ),
                ),
                if (number != null || teamName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (number != null) '#$number',
                      if (teamName.isNotEmpty) teamName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (positions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    positions,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: mutedTextColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (hasStats) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      statsSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
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

  Widget _fallbackBg(Color color, String initials) {
    return ColoredBox(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.12),
        const Color(0xFF0B1220),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.oswald(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 44,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
