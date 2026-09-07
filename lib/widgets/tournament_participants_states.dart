import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../utils/tournament_participants_helpers.dart';

/// Catálogo derivado memoizado para la sección Participantes.
class TournamentParticipantsCatalog {
  TournamentParticipantsCatalog({
    required List<Map<String, dynamic>> teams,
    required List<dynamic> tournamentCategories,
  })  : omittedTeamsWithoutAcademy =
            TournamentParticipantsHelpers.countTeamsWithoutAcademyId(teams),
        allGroupedAcademies =
            TournamentParticipantsHelpers.groupTeamsByAcademy(teams),
        availableCategories =
            TournamentParticipantsHelpers.buildAvailableCategories(
              teams,
              tournamentCategories,
            );

  final List<TournamentAcademyGroup> allGroupedAcademies;
  final List<TournamentCategoryFilterOption> availableCategories;
  final int omittedTeamsWithoutAcademy;

  List<TournamentAcademyVisibleGroup> visibleAcademies(String? selectedCategoryKey) {
    return TournamentParticipantsHelpers.buildVisibleAcademies(
      allGroupedAcademies,
      selectedCategoryKey,
    );
  }
}

/// Skeleton del grid de academias (carga inicial).
class TournamentParticipantsGridSkeleton extends StatefulWidget {
  const TournamentParticipantsGridSkeleton({
    super.key,
    required this.availableWidth,
  });

  final double availableWidth;

  @override
  State<TournamentParticipantsGridSkeleton> createState() =>
      _TournamentParticipantsGridSkeletonState();
}

class _TournamentParticipantsGridSkeletonState
    extends State<TournamentParticipantsGridSkeleton>
    with SingleTickerProviderStateMixin {
  static const double _horizontalPadding = 16;
  static const double _spacing = 12;

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
    final crossAxisCount =
        TournamentParticipantsHelpers.gridCrossAxisCount(widget.availableWidth);
    final itemCount = crossAxisCount >= 3 ? 6 : 4;
    final gridWidth = widget.availableWidth - _horizontalPadding * 2;
    final cellWidth =
        (gridWidth - _spacing * (crossAxisCount - 1)) / crossAxisCount;
    final rowCount = (itemCount / crossAxisCount).ceil();
    final gridHeight = rowCount * cellWidth + (rowCount - 1) * _spacing;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = 0.28 + (_pulseController.value * 0.18);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            _horizontalPadding,
            0,
            _horizontalPadding,
            32,
          ),
          child: SizedBox(
            height: gridHeight,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: _spacing,
                crossAxisSpacing: _spacing,
                childAspectRatio: 1.0,
              ),
              itemCount: itemCount,
              itemBuilder: (_, index) => _SkeletonCard(opacity: pulse),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.opacity});

  final double opacity;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final base = Color.fromRGBO(30, 41, 59, opacity);
    final highlight = Color.fromRGBO(51, 65, 85, opacity * 0.85);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF151D2E),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 56,
              height: 20,
              decoration: BoxDecoration(
                color: highlight,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 72,
                  decoration: BoxDecoration(
                    color: highlight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TournamentParticipantsLoadingView extends StatelessWidget {
  const TournamentParticipantsLoadingView({super.key});

  static const double _horizontalPadding = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  12,
                  _horizontalPadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SkeletonLine(width: width * 0.42, height: 13),
                    const SizedBox(height: 12),
                    _SkeletonLine(width: width - _horizontalPadding * 2, height: 46),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: TournamentParticipantsGridSkeleton(availableWidth: width),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(height > 20 ? 12 : 6),
      ),
    );
  }
}

class TournamentParticipantsEmptyState extends StatelessWidget {
  const TournamentParticipantsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 16),
            Text(
              'AÚN NO HAY PARTICIPANTES',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las academias inscritas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentParticipantsErrorState extends StatelessWidget {
  const TournamentParticipantsErrorState({
    super.key,
    required this.onRetry,
    required this.isRetrying,
  });

  final VoidCallback onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 16),
            Text(
              'NO SE PUDIERON CARGAR LOS PARTICIPANTES',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revisa tu conexión e inténtalo nuevamente.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isRetrying ? null : onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: const Color(0xFF0B101E),
                disabledBackgroundColor:
                    AppTheme.brandTeal.withValues(alpha: 0.45),
              ),
              child: isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B101E),
                      ),
                    )
                  : Text(
                      'REINTENTAR',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentParticipantsRefreshBanner extends StatelessWidget {
  const TournamentParticipantsRefreshBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.brandTeal,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Actualizando participantes…',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
