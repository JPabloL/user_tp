import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/award_score_format.dart';
import '../utils/match_award_detail_builder.dart';
import '../utils/match_awards.dart';
import '../utils/match_helpers.dart';
import 'match_award_card.dart';
import 'match_award_detail_sheet.dart';
import 'match_awards_player_scores_sheet.dart';
import 'match_mvp_card.dart';

/// Sección de reconocimientos del partido (estructura y visibilidad).
/// No calcula puntuaciones; consume únicamente [matchAwards].
class MatchAwardsSection extends StatefulWidget {
  const MatchAwardsSection({
    super.key,
    required this.matchAwards,
    this.homeTeam = const {},
    this.visitorTeam = const {},
    this.surfaceColor = const Color(0xFF1E293B),
    this.accentColor = const Color(0xFF2DD4BF),
    this.visitColor = const Color(0xFFE040FB),
    this.mutedTextColor = const Color(0xFF94A3B8),
    this.resolveMediaUrl,
  });

  final MatchAwardsResult matchAwards;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> visitorTeam;
  final Color surfaceColor;
  final Color accentColor;
  final Color visitColor;
  final Color mutedTextColor;
  final String Function(String)? resolveMediaUrl;

  @override
  State<MatchAwardsSection> createState() => _MatchAwardsSectionState();
}

class _MatchAwardsSectionState extends State<MatchAwardsSection> {
  final ScrollController _carouselController = ScrollController();
  late ValueNotifier<MatchAwardsResult> _awardsNotifier;

  bool _snapshotsReady = false;
  String? _featuredPlayerId;
  String? _offensivePlayerId;
  String? _defensivePlayerId;

  bool _showFeaturedUpdated = false;
  bool _showOffensiveUpdated = false;
  bool _showDefensiveUpdated = false;

  Timer? _featuredTimer;
  Timer? _offensiveTimer;
  Timer? _defensiveTimer;

  MatchAwardCategory? _openSheetCategory;

  @override
  void initState() {
    super.initState();
    _awardsNotifier = ValueNotifier(widget.matchAwards);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureSnapshots();
      _snapshotsReady = true;
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _awardsNotifier.dispose();
    _featuredTimer?.cancel();
    _offensiveTimer?.cancel();
    _defensiveTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchAwardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.matchAwards != oldWidget.matchAwards) {
      if (_snapshotsReady) {
        _detectLeaderChanges(widget.matchAwards);
      }
      _awardsNotifier.value = widget.matchAwards;
      _captureSnapshots();

      if (_openSheetCategory != null &&
          !categoryExists(widget.matchAwards, _openSheetCategory!)) {
        Navigator.of(context).maybePop();
        _openSheetCategory = null;
      }
    }
  }

  bool get _hasMvp => widget.matchAwards.hasMvp;

  bool get _hasCalculatedAwards =>
      widget.matchAwards.hasFeaturedPlayer ||
      widget.matchAwards.hasOffensiveLeader ||
      widget.matchAwards.hasDefensiveLeader;

  String Function(String) get _mediaResolver =>
      widget.resolveMediaUrl ?? MatchHelpers.resolveMediaUrl;

  MatchAwardDetailBuilder _detailBuilder(MatchAwardsResult awards) {
    return MatchAwardDetailBuilder(
      matchAwards: awards,
      homeTeam: widget.homeTeam,
      visitorTeam: widget.visitorTeam,
      homeColor: widget.accentColor,
      visitColor: widget.visitColor,
    );
  }

  void _captureSnapshots() {
    final awards = widget.matchAwards;
    _featuredPlayerId = _playerId(awards.featuredPlayer?.player);
    _offensivePlayerId = _playerId(awards.offensiveLeader?.player);
    _defensivePlayerId = _playerId(awards.defensiveLeader?.player);
  }

  void _detectLeaderChanges(MatchAwardsResult awards) {
    final newFeaturedId = _playerId(awards.featuredPlayer?.player);
    if (_featuredPlayerId != null &&
        newFeaturedId != null &&
        _featuredPlayerId != newFeaturedId) {
      _flashLeaderUpdated(
        () => _showFeaturedUpdated = true,
        (t) => _featuredTimer = t,
        () => _showFeaturedUpdated = false,
      );
    }

    final newOffId = _playerId(awards.offensiveLeader?.player);
    if (_offensivePlayerId != null &&
        newOffId != null &&
        _offensivePlayerId != newOffId) {
      _flashLeaderUpdated(
        () => _showOffensiveUpdated = true,
        (t) => _offensiveTimer = t,
        () => _showOffensiveUpdated = false,
      );
    }

    final newDefId = _playerId(awards.defensiveLeader?.player);
    if (_defensivePlayerId != null &&
        newDefId != null &&
        _defensivePlayerId != newDefId) {
      _flashLeaderUpdated(
        () => _showDefensiveUpdated = true,
        (t) => _defensiveTimer = t,
        () => _showDefensiveUpdated = false,
      );
    }
  }

  void _flashLeaderUpdated(
    void Function() show,
    void Function(Timer) storeTimer,
    void Function() hide,
  ) {
    show();
    storeTimer(
      Timer(const Duration(milliseconds: 1750), () {
        if (!mounted) return;
        hide();
        setState(() {});
      }),
    );
    setState(() {});
  }

  String? _playerId(Map<String, dynamic>? player) {
    if (player == null) return null;
    final id = (player['_id'] ?? player['id'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  void _openDetailSheet(MatchAwardCategory category) {
    final payload = _detailBuilder(widget.matchAwards).forCategory(category);
    if (payload == null) return;

    _openSheetCategory = category;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ValueListenableBuilder<MatchAwardsResult>(
          valueListenable: _awardsNotifier,
          builder: (context, awards, _) {
            final live = _detailBuilder(awards).forCategory(category);
            if (live == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).maybePop();
                }
              });
              return const SizedBox.shrink();
            }
            return MatchAwardDetailSheet(
              payload: live,
              mutedTextColor: widget.mutedTextColor,
              surfaceColor: widget.surfaceColor,
              resolveMediaUrl: _mediaResolver,
            );
          },
        );
      },
    ).whenComplete(() => _openSheetCategory = null);
  }

  void _openPlayerScoresSheet() {
    MatchAwardsPlayerScoresSheet.show(
      context,
      playerScores: widget.matchAwards.playerScores,
      homeTeamName:
          MatchHelpers.teamDisplayName(widget.homeTeam, fallback: 'LOCAL'),
      visitorTeamName:
          MatchHelpers.teamDisplayName(widget.visitorTeam, fallback: 'VISITA'),
      homeTeamLogoUrl: MatchHelpers.teamLogoUrl(widget.homeTeam),
      visitorTeamLogoUrl: MatchHelpers.teamLogoUrl(widget.visitorTeam),
      homeColor: widget.accentColor,
      visitColor: widget.visitColor,
      mutedTextColor: widget.mutedTextColor,
      surfaceColor: widget.surfaceColor,
      resolveMediaUrl: _mediaResolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.matchAwards.hasAnyAward) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        _SectionHeader(
          accentColor: widget.accentColor,
          mutedTextColor: widget.mutedTextColor,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _hasMvp
              ? Padding(
                  key: const ValueKey('mvp-slot'),
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildMvpCard(widget.matchAwards.mvp!),
                )
              : const SizedBox.shrink(key: ValueKey('mvp-empty')),
        ),
        if (_hasCalculatedAwards) ...[
          SizedBox(height: _hasMvp ? 16 : 14),
          _CalculatedAwardsCarousel(
            matchAwards: widget.matchAwards,
            controller: _carouselController,
            homeTeam: widget.homeTeam,
            visitorTeam: widget.visitorTeam,
            homeColor: widget.accentColor,
            visitColor: widget.visitColor,
            surfaceColor: widget.surfaceColor,
            mutedTextColor: widget.mutedTextColor,
            resolveMediaUrl: _mediaResolver,
            showFeaturedUpdated: _showFeaturedUpdated,
            showOffensiveUpdated: _showOffensiveUpdated,
            showDefensiveUpdated: _showDefensiveUpdated,
            onOpenDetail: _openDetailSheet,
          ),
        ],
        if (widget.matchAwards.hasPlayerScores) ...[
          const SizedBox(height: 16),
          _PlayerScoresOpenButton(
            playerCount: widget.matchAwards.playerScores.length,
            accentColor: widget.accentColor,
            mutedTextColor: widget.mutedTextColor,
            surfaceColor: widget.surfaceColor,
            onTap: _openPlayerScoresSheet,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMvpCard(MvpAward mvp) {
    final player = mvp.player;
    final teamCtx = _teamContextForPlayer(player);

    return MatchMvpCard(
      key: const ValueKey('mvp'),
      player: player,
      teamName: teamCtx.name,
      teamLogoUrl: teamCtx.logoUrl,
      teamColor: teamCtx.color,
      source: mvp.source,
      surfaceColor: widget.surfaceColor,
      mutedTextColor: widget.mutedTextColor,
      resolveMediaUrl: _mediaResolver,
      onTap: () => _openDetailSheet(MatchAwardCategory.mvp),
    );
  }

  _TeamVisualContext _teamContextForPlayer(Map<String, dynamic> player) {
    final isHome = player['isHome'] == true;
    final team = isHome
        ? MatchHelpers.asMap(widget.homeTeam)
        : MatchHelpers.asMap(widget.visitorTeam);
    return _TeamVisualContext(
      name: MatchHelpers.teamDisplayName(
        team,
        fallback: (player['teamName'] ?? '').toString(),
      ),
      logoUrl: MatchHelpers.teamLogoUrl(team),
      color: isHome ? widget.accentColor : widget.visitColor,
    );
  }
}

class _TeamVisualContext {
  const _TeamVisualContext({
    required this.name,
    required this.logoUrl,
    required this.color,
  });

  final String name;
  final String logoUrl;
  final Color color;
}

class _PlayerScoresOpenButton extends StatelessWidget {
  const _PlayerScoresOpenButton({
    required this.playerCount,
    required this.accentColor,
    required this.mutedTextColor,
    required this.surfaceColor,
    required this.onTap,
  });

  final int playerCount;
  final Color accentColor;
  final Color mutedTextColor;
  final Color surfaceColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VER PUNTUACIÓN POR JUGADOR',
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$playerCount jugadores con impacto registrado',
                      style: GoogleFonts.inter(
                        color: mutedTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: mutedTextColor.withValues(alpha: 0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.accentColor,
    required this.mutedTextColor,
  });

  final Color accentColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.star_rounded,
              size: 11,
              color: accentColor.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              'RECONOCIMIENTOS DEL PARTIDO',
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Rendimiento individual',
          style: GoogleFonts.inter(
            color: mutedTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CalculatedAwardsCarousel extends StatelessWidget {
  const _CalculatedAwardsCarousel({
    required this.matchAwards,
    required this.controller,
    required this.homeTeam,
    required this.visitorTeam,
    required this.homeColor,
    required this.visitColor,
    required this.surfaceColor,
    required this.mutedTextColor,
    required this.resolveMediaUrl,
    required this.onOpenDetail,
    this.showFeaturedUpdated = false,
    this.showOffensiveUpdated = false,
    this.showDefensiveUpdated = false,
  });

  final MatchAwardsResult matchAwards;
  final ScrollController controller;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> visitorTeam;
  final Color homeColor;
  final Color visitColor;
  final Color surfaceColor;
  final Color mutedTextColor;
  final String Function(String) resolveMediaUrl;
  final void Function(MatchAwardCategory category) onOpenDetail;
  final bool showFeaturedUpdated;
  final bool showOffensiveUpdated;
  final bool showDefensiveUpdated;

  static const double _heroHeight = 280;
  static const double _secondaryHeight = 218;
  static const double _secondaryCardWidth = 168;
  static const double _cardSpacing = 11;

  _TeamVisualContext _teamContextForPlayer(Map<String, dynamic> player) {
    final isHome = player['isHome'] == true;
    final team = isHome
        ? MatchHelpers.asMap(homeTeam)
        : MatchHelpers.asMap(visitorTeam);
    return _TeamVisualContext(
      name: MatchHelpers.teamDisplayName(
        team,
        fallback: (player['teamName'] ?? '').toString(),
      ),
      logoUrl: MatchHelpers.teamLogoUrl(team),
      color: isHome ? homeColor : visitColor,
    );
  }

  String _featuredSupportingText(FeaturedPlayerAward award) {
    final parts = <String>[];
    if (award.activeFamilies > 0) {
      parts.add('${award.activeFamilies} ÁREAS');
    }
    if (award.contextualBonus > 0) {
      parts.add(
        '+${formatAwardDisplayScore(award.contextualBonus)} CONTEXTO',
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final viewportWidth = screenWidth - 32;

    final featured = matchAwards.featuredPlayer;
    final hasFeatured = matchAwards.hasFeaturedPlayer &&
        featured != null &&
        featured.player != null;

    final hasOffensive = matchAwards.hasOffensiveLeader &&
        matchAwards.offensiveLeader != null;
    final hasDefensive = matchAwards.hasDefensiveLeader &&
        matchAwards.defensiveLeader != null;
    final secondaryCount = (hasOffensive ? 1 : 0) + (hasDefensive ? 1 : 0);
    final secondaryWidth = _secondaryWidthForLayout(viewportWidth, secondaryCount);

  if (!hasFeatured && secondaryCount == 0) {
      return const SizedBox.shrink();
    }

    Widget? featuredCard;
    if (hasFeatured) {
      final player = featured.player!;
      final teamCtx = _teamContextForPlayer(player);
      featuredCard = MatchAwardCard(
        key: const ValueKey('featuredPlayer'),
        awardType: MatchAwardType.featuredPlayer,
        title: 'JUGADOR DESTACADO',
        subtitle: 'IMPACTO INTEGRAL',
        player: player,
        teamName: teamCtx.name,
        teamLogoUrl: teamCtx.logoUrl,
        teamColor: teamCtx.color,
        score: featured.integralImpactScore,
        scoreLabel: 'PUNTOS DE IMPACTO',
        icon: Icons.bolt_rounded,
        supportingText: _featuredSupportingText(featured),
        surfaceColor: surfaceColor,
        mutedTextColor: mutedTextColor,
        tiedPlayers: featured.tiedPlayers,
        resolveMediaUrl: resolveMediaUrl,
        width: viewportWidth,
        height: _heroHeight,
        showLeaderUpdated: showFeaturedUpdated,
        variant: MatchAwardSpotlightVariant.hero,
        onTap: () => onOpenDetail(MatchAwardCategory.featuredPlayer),
      );
    }

    final secondarySlots = <Widget>[];

    if (hasOffensive) {
      final offensive = matchAwards.offensiveLeader!;
      final player = offensive.player;
      final teamCtx = _teamContextForPlayer(player);
      secondarySlots.add(
        MatchAwardCard(
          key: const ValueKey('offensiveLeader'),
          awardType: MatchAwardType.offensiveLeader,
          title: 'LÍDER OFENSIVO',
          subtitle: 'PRODUCCIÓN OFENSIVA',
          player: player,
          teamName: teamCtx.name,
          teamLogoUrl: teamCtx.logoUrl,
          teamColor: teamCtx.color,
          score: offensive.score,
          scoreLabel: 'IMPACTO OFENSIVO',
          icon: Icons.arrow_forward_rounded,
          supportingText: 'PASE · RECEPCIÓN · CARRERA',
          surfaceColor: surfaceColor,
          mutedTextColor: mutedTextColor,
          tiedPlayers: offensive.tiedPlayers,
          resolveMediaUrl: resolveMediaUrl,
          width: secondaryWidth,
          height: _secondaryHeight,
          showLeaderUpdated: showOffensiveUpdated,
          variant: MatchAwardSpotlightVariant.secondary,
          onTap: () => onOpenDetail(MatchAwardCategory.offensiveLeader),
        ),
      );
    }

    if (hasDefensive) {
      final defensive = matchAwards.defensiveLeader!;
      final player = defensive.player;
      final teamCtx = _teamContextForPlayer(player);
      secondarySlots.add(
        MatchAwardCard(
          key: const ValueKey('defensiveLeader'),
          awardType: MatchAwardType.defensiveLeader,
          title: 'LÍDER DEFENSIVO',
          subtitle: 'PRODUCCIÓN DEFENSIVA',
          player: player,
          teamName: teamCtx.name,
          teamLogoUrl: teamCtx.logoUrl,
          teamColor: teamCtx.color,
          score: defensive.score,
          scoreLabel: 'IMPACTO DEFENSIVO',
          icon: Icons.shield_outlined,
          supportingText: 'SACK · SAFETY · INTERCEPCIÓN',
          surfaceColor: surfaceColor,
          mutedTextColor: mutedTextColor,
          tiedPlayers: defensive.tiedPlayers,
          resolveMediaUrl: resolveMediaUrl,
          width: secondaryWidth,
          height: _secondaryHeight,
          showLeaderUpdated: showDefensiveUpdated,
          variant: MatchAwardSpotlightVariant.secondary,
          onTap: () => onOpenDetail(MatchAwardCategory.defensiveLeader),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (featuredCard != null) featuredCard,
        if (featuredCard != null && secondarySlots.isNotEmpty)
          const SizedBox(height: 14),
        if (secondarySlots.length == 2 && viewportWidth >= 340)
          Row(
            children: [
              Expanded(child: secondarySlots[0]),
              const SizedBox(width: _cardSpacing),
              Expanded(child: secondarySlots[1]),
            ],
          )
        else if (secondarySlots.isNotEmpty)
          SizedBox(
            height: _secondaryHeight,
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              itemCount: secondarySlots.length,
              separatorBuilder: (_, _) => const SizedBox(width: _cardSpacing),
              itemBuilder: (_, index) => secondarySlots[index],
            ),
          ),
      ],
    );
  }

  double _secondaryWidthForLayout(double viewportWidth, int count) {
    if (count >= 2 && viewportWidth >= 340) {
      return (viewportWidth - _cardSpacing) / 2;
    }
    return math.min(_secondaryCardWidth, viewportWidth - 28);
  }
}
