import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../utils/match_helpers.dart';
import 'next_battle_card.dart';

/// Card de partido idéntica al listado, con fecha opcional fuera de la card.
class UserRelatedMatchCard extends StatelessWidget {
  const UserRelatedMatchCard({
    super.key,
    required this.match,
    required this.resolveMediaUrl,
    this.onTap,
    this.cardMargin = const EdgeInsets.only(bottom: 11),
    this.showDateAboveCard = false,
  });

  final Map<String, dynamic> match;
  final String Function(String) resolveMediaUrl;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? cardMargin;
  final bool showDateAboveCard;

  String _carouselDateLabel() {
    final day = MatchHelpers.matchLocalDay(match);
    if (day == null) return 'SIN FECHA';
    return MatchHelpers.formatCarouselMatchDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final side = MatchHelpers.playerSideForMatch(match);
    final academy = MatchHelpers.academyInfoForMatch(match, side);

    final card = NextBattleCard(
      match: match,
      myAcademyName: academy.name,
      academyId: academy.id,
      forcedIsHome: side == 'home'
          ? true
          : side == 'visitor'
          ? false
          : null,
      layout: MatchCardLayout.list,
      cardMargin: cardMargin,
      showLiveTicker: false,
      onTap: onTap,
      resolveMediaUrl: resolveMediaUrl,
    );

    if (!showDateAboveCard) return card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Text(
            _carouselDateLabel(),
            style: GoogleFonts.oswald(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandTeal,
              letterSpacing: 1.1,
            ),
          ),
        ),
        card,
      ],
    );
  }
}
