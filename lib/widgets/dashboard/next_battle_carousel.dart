import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/user_matches_store.dart';
import '../../utils/match_helpers.dart';
import 'user_related_match_card.dart';

class NextBattleCarousel extends StatefulWidget {
  const NextBattleCarousel({
    super.key,
    required this.matches,
    required this.resolveMediaUrl,
    required this.onMatchTap,
    this.title = 'PRÓXIMA BATALLA',
  });

  final List<Map<String, dynamic>> matches;
  final String Function(String) resolveMediaUrl;
  final void Function(Map<String, dynamic> match) onMatchTap;
  final String title;

  @override
  State<NextBattleCarousel> createState() => _NextBattleCarouselState();
}

class _NextBattleCarouselState extends State<NextBattleCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NextBattleCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentPage >= widget.matches.length) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.matches.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final match = widget.matches[index];
              return UserRelatedMatchCard(
                key: ValueKey(MatchHelpers.matchId(match)),
                match: match,
                resolveMediaUrl: widget.resolveMediaUrl,
                onTap: () => widget.onMatchTap(match),
                showDateAboveCard: true,
                cardMargin: const EdgeInsets.only(bottom: 0),
              );
            },
          ),
        ),
        if (widget.matches.length > 1) ...[
          const SizedBox(height: 8),
          _buildPageIndicator(widget.matches.length),
        ],
      ],
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.brandTeal : Colors.white24,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

/// Escucha [UserMatchesStore] y muestra el carrusel cuando hay partidos.
class NextBattleCarouselSection extends StatelessWidget {
  const NextBattleCarouselSection({
    super.key,
    required this.store,
    required this.hasBrandLogo,
    required this.resolveMediaUrl,
    required this.onMatchTap,
    this.title = 'PRÓXIMA BATALLA',
  });

  final UserMatchesStore store;
  final bool hasBrandLogo;
  final String Function(String) resolveMediaUrl;
  final void Function(Map<String, dynamic> match) onMatchTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final matches = store.getCarouselMatches();
        if (!hasBrandLogo || matches.isEmpty) return const SizedBox.shrink();

        return NextBattleCarousel(
          matches: matches,
          resolveMediaUrl: resolveMediaUrl,
          onMatchTap: onMatchTap,
          title: title,
        );
      },
    );
  }
}
