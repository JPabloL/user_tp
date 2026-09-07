import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/award_score_format.dart';
import '../utils/match_awards.dart';
import '../utils/match_helpers.dart';
import 'match_award_media.dart';

/// Bottom sheet con puntuación por jugador en tabs por equipo.
class MatchAwardsPlayerScoresSheet extends StatefulWidget {
  const MatchAwardsPlayerScoresSheet({
    super.key,
    required this.playerScores,
    required this.homeTeamName,
    required this.visitorTeamName,
    required this.homeTeamLogoUrl,
    required this.visitorTeamLogoUrl,
    required this.homeColor,
    required this.visitColor,
    required this.mutedTextColor,
    this.surfaceColor = const Color(0xFF1E293B),
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
  });

  final List<PlayerMatchAwardScore> playerScores;
  final String homeTeamName;
  final String visitorTeamName;
  final String homeTeamLogoUrl;
  final String visitorTeamLogoUrl;
  final Color homeColor;
  final Color visitColor;
  final Color mutedTextColor;
  final Color surfaceColor;
  final String Function(String) resolveMediaUrl;

  static Future<void> show(
    BuildContext context, {
    required List<PlayerMatchAwardScore> playerScores,
    required String homeTeamName,
    required String visitorTeamName,
    required String homeTeamLogoUrl,
    required String visitorTeamLogoUrl,
    required Color homeColor,
    required Color visitColor,
    required Color mutedTextColor,
    Color surfaceColor = const Color(0xFF1E293B),
    String Function(String) resolveMediaUrl = MatchHelpers.resolveMediaUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MatchAwardsPlayerScoresSheet(
        playerScores: playerScores,
        homeTeamName: homeTeamName,
        visitorTeamName: visitorTeamName,
        homeTeamLogoUrl: homeTeamLogoUrl,
        visitorTeamLogoUrl: visitorTeamLogoUrl,
        homeColor: homeColor,
        visitColor: visitColor,
        mutedTextColor: mutedTextColor,
        surfaceColor: surfaceColor,
        resolveMediaUrl: resolveMediaUrl,
      ),
    );
  }

  @override
  State<MatchAwardsPlayerScoresSheet> createState() =>
      _MatchAwardsPlayerScoresSheetState();
}

class _MatchAwardsPlayerScoresSheetState
    extends State<MatchAwardsPlayerScoresSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PlayerMatchAwardScore> _scoresForTeam(bool isHome) {
    final list = widget.playerScores
        .where((e) => e.player['isHome'] == isHome)
        .toList();
    list.sort((a, b) => b.integralImpactScore.compareTo(a.integralImpactScore));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final homeScores = _scoresForTeam(true);
    final visitScores = _scoresForTeam(false);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: sheetHeight,
      margin: const EdgeInsets.only(top: 48),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: widget.homeColor.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PUNTUACIÓN POR JUGADOR',
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Impacto integral del partido por equipo',
                  style: GoogleFonts.inter(
                    color: widget.mutedTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              indicatorColor: widget.homeColor,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: widget.mutedTextColor,
              labelStyle: GoogleFonts.oswald(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              unselectedLabelStyle: GoogleFonts.oswald(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: widget.homeTeamName.toUpperCase()),
                Tab(text: widget.visitorTeamName.toUpperCase()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TeamScoresTab(
                  scores: homeScores,
                  teamName: widget.homeTeamName,
                  teamLogoUrl: widget.homeTeamLogoUrl,
                  teamColor: widget.homeColor,
                  mutedTextColor: widget.mutedTextColor,
                  resolveMediaUrl: widget.resolveMediaUrl,
                  bottomInset: bottomInset,
                ),
                _TeamScoresTab(
                  scores: visitScores,
                  teamName: widget.visitorTeamName,
                  teamLogoUrl: widget.visitorTeamLogoUrl,
                  teamColor: widget.visitColor,
                  mutedTextColor: widget.mutedTextColor,
                  resolveMediaUrl: widget.resolveMediaUrl,
                  bottomInset: bottomInset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamScoresTab extends StatelessWidget {
  const _TeamScoresTab({
    required this.scores,
    required this.teamName,
    required this.teamLogoUrl,
    required this.teamColor,
    required this.mutedTextColor,
    required this.resolveMediaUrl,
    required this.bottomInset,
  });

  final List<PlayerMatchAwardScore> scores;
  final String teamName;
  final String teamLogoUrl;
  final Color teamColor;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Text(
            'Sin jugadores con impacto registrado',
            style: GoogleFonts.inter(color: mutedTextColor, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
      itemCount: scores.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (teamLogoUrl.isNotEmpty) ...[
                  MatchAwardTeamLogoChip(
                    logoUrl: teamLogoUrl,
                    teamColor: teamColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    teamName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.oswald(
                      color: teamColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${scores.length} jugadores',
                  style: GoogleFonts.inter(
                    color: mutedTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final entry = scores[index - 1];
        return _PlayerScoreRow(
          rank: index,
          entry: entry,
          teamColor: teamColor,
          mutedTextColor: mutedTextColor,
          resolveMediaUrl: resolveMediaUrl,
        );
      },
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  const _PlayerScoreRow({
    required this.rank,
    required this.entry,
    required this.teamColor,
    required this.mutedTextColor,
    required this.resolveMediaUrl,
  });

  final int rank;
  final PlayerMatchAwardScore entry;
  final Color teamColor;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;

  @override
  Widget build(BuildContext context) {
    final player = entry.player;
    final name = MatchHelpers.playerDisplayName(player);
    final number = MatchHelpers.formatPlayerNumber(player['number']);
    final impact = formatAwardDisplayScore(entry.integralImpactScore);
    final detail = [
      if (entry.offensiveScore > 0)
        'OF ${formatAwardDisplayScore(entry.offensiveScore)}',
      if (entry.defensiveScore > 0)
        'DF ${formatAwardDisplayScore(entry.defensiveScore)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: GoogleFonts.oswald(
                color: Colors.white24,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          MatchAwardPlayerPhoto(
            player: player,
            teamColor: teamColor,
            size: 36,
            resolveMediaUrl: resolveMediaUrl,
            useSpotlightPhoto: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    if (number != null) '#$number',
                    if (detail.isNotEmpty) detail,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: mutedTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                impact,
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                'IMPACTO',
                style: GoogleFonts.inter(
                  color: teamColor.withValues(alpha: 0.85),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
