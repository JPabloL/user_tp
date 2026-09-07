import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/academy_profile_models.dart';
import '../../utils/academy_profile_view_data.dart';
import '../../utils/academy_stats_helpers.dart';
import 'academy_profile_sections.dart';

class AcademyProfileStatsTab extends StatefulWidget {
  const AcademyProfileStatsTab({
    super.key,
    required this.viewData,
  });

  final AcademyProfileViewData viewData;

  @override
  State<AcademyProfileStatsTab> createState() => _AcademyProfileStatsTabState();
}

class _AcademyProfileStatsTabState extends State<AcademyProfileStatsTab>
    with AutomaticKeepAliveClientMixin {
  String? _selectedCategoryKey;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final data = widget.viewData.context;
    final sortedYearStats = widget.viewData.sortedYearStats;
    final overall = data.record.overall;
    final hasMatches = AcademyStatsHelpers.hasEnoughMatches(overall);
    final categoryStats = data.categoryStats;

    if (!hasMatches &&
        !AcademyStatsHelpers.hasRecordActivity(data.record.regular) &&
        !AcademyStatsHelpers.hasRecordActivity(data.record.playoffs) &&
        categoryStats.isEmpty &&
        sortedYearStats.isEmpty) {
      return CustomScrollView(
        key: const PageStorageKey<String>('academy_tab_estadisticas'),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No hay suficientes partidos registrados para generar estadísticas.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final standingsStats = data.record.regularSeasonFromStandings;

    return CustomScrollView(
      key: const PageStorageKey<String>('academy_tab_estadisticas'),
      slivers: [
        if (hasMatches)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                child: _OverallRecordSection(record: overall),
              ),
            ),
          ),
        if (AcademyStatsHelpers.hasRecordActivity(data.record.regular) ||
            AcademyStatsHelpers.hasRecordActivity(data.record.playoffs))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 40,
                child: _PhaseComparisonSection(
                  regular: data.record.regular,
                  playoffs: data.record.playoffs,
                ),
              ),
            ),
          ),
        if (overall.internalMatches > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${AcademyStatsHelpers.formatCount(overall.internalMatches)} partidos fueron disputados entre equipos de la propia academia y no se contabilizan como victoria o derrota general.',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ),
          ),
        if (standingsStats.hasData)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 60,
                child: _StandingsStatsSection(stats: standingsStats),
              ),
            ),
          ),
        if (categoryStats.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 80,
                child: _CategoryStatsSection(
                  stats: categoryStats,
                  selectedKey: _selectedCategoryKey,
                  onSelected: (key) =>
                      setState(() => _selectedCategoryKey = key),
                ),
              ),
            ),
          ),
        if (sortedYearStats.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            sliver: SliverToBoxAdapter(
              child: AcademyProfileFadeIn(
                delayMs: 100,
                child: _YearStatsSection(yearStats: sortedYearStats),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _OverallRecordSection extends StatelessWidget {
  const _OverallRecordSection({required this.record});

  final AcademyRecord record;

  @override
  Widget build(BuildContext context) {
    final played = AcademyStatsHelpers.effectivePlayed(record);
    final winLabel = AcademyStatsHelpers.formatWinPctLabel(record.winPctPercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AcademyProfileSectionTitle(title: 'Récord en TOCHITOPRO'),
        const SizedBox(height: 16),
        Text(
          '${AcademyStatsHelpers.formatCount(played)} PJ',
          style: GoogleFonts.oswald(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '${AcademyStatsHelpers.formatCount(record.wins)} G',
                style: GoogleFonts.oswald(
                  color: AppTheme.brandTeal,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${AcademyStatsHelpers.formatCount(record.losses)} P',
                style: GoogleFonts.oswald(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (winLabel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            winLabel,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _WinLossBar(
          wins: record.wins,
          losses: record.losses,
          ties: record.ties,
        ),
        if (record.ties > 0) ...[
          const SizedBox(height: 10),
          Text(
            '${AcademyStatsHelpers.formatCount(record.ties)} empates',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _StatMini(
              label: 'PF',
              value: AcademyStatsHelpers.formatCount(record.pointsFor),
            ),
            _StatMini(
              label: 'PC',
              value: AcademyStatsHelpers.formatCount(record.pointsAgainst),
            ),
            _StatMini(
              label: 'DIF',
              value: AcademyStatsHelpers.formatDiff(record.pointDiff),
              highlight: record.pointDiff > 0,
            ),
          ],
        ),
      ],
    );
  }
}

class _WinLossBar extends StatelessWidget {
  const _WinLossBar({
    required this.wins,
    required this.losses,
    required this.ties,
  });

  final int wins;
  final int losses;
  final int ties;

  @override
  Widget build(BuildContext context) {
    final total = wins + losses + ties;
    final winFlex = total > 0 ? wins : 0;
    final lossFlex = total > 0 ? losses : 0;
    final tieFlex = total > 0 ? ties : 0;
    final emptyFlex = total == 0 ? 1 : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (winFlex > 0)
              Expanded(
                flex: winFlex,
                child: ColoredBox(color: AppTheme.brandTeal.withValues(alpha: 0.85)),
              ),
            if (tieFlex > 0)
              Expanded(
                flex: tieFlex,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
            if (lossFlex > 0)
              Expanded(
                flex: lossFlex,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            if (emptyFlex > 0)
              Expanded(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.oswald(
            color: highlight ? AppTheme.brandTeal : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PhaseComparisonSection extends StatelessWidget {
  const _PhaseComparisonSection({
    required this.regular,
    required this.playoffs,
  });

  final AcademyRecord regular;
  final AcademyRecord playoffs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _PhaseBlock(
                title: 'FASE REGULAR',
                record: regular,
                emphasize: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PhaseBlock(
                title: 'PLAYOFFS',
                record: playoffs,
                emphasize: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhaseBlock extends StatelessWidget {
  const _PhaseBlock({
    required this.title,
    required this.record,
    required this.emphasize,
  });

  final String title;
  final AcademyRecord record;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    if (!AcademyStatsHelpers.hasRecordActivity(record)) {
      return const SizedBox.shrink();
    }

    final played = AcademyStatsHelpers.effectivePlayed(record);
    final winPct = AcademyStatsHelpers.formatWinPctPercent(record.winPctPercent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize
            ? AppTheme.brandTeal.withValues(alpha: 0.07)
            : AppTheme.navySurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize
              ? AppTheme.brandTeal.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: emphasize ? AppTheme.brandTeal : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _PhaseLine(
            label: 'PJ',
            value: AcademyStatsHelpers.formatCount(played),
          ),
          _PhaseLine(
            label: 'G',
            value: AcademyStatsHelpers.formatCount(record.wins),
          ),
          _PhaseLine(
            label: 'P',
            value: AcademyStatsHelpers.formatCount(record.losses),
          ),
          if (winPct.isNotEmpty)
            _PhaseLine(label: '%', value: winPct),
          _PhaseLine(
            label: 'PF',
            value: AcademyStatsHelpers.formatCount(record.pointsFor),
          ),
          _PhaseLine(
            label: 'PC',
            value: AcademyStatsHelpers.formatCount(record.pointsAgainst),
          ),
        ],
      ),
    );
  }
}

class _PhaseLine extends StatelessWidget {
  const _PhaseLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingsStatsSection extends StatelessWidget {
  const _StandingsStatsSection({required this.stats});

  final AcademyRegularSeasonFromStandings stats;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (stats.firstPlaces > 0) {
      lines.add('${stats.firstPlaces} veces 1°');
    }
    if (stats.secondPlaces > 0) {
      lines.add('${stats.secondPlaces} veces 2°');
    }
    if (stats.thirdPlaces > 0) {
      lines.add('${stats.thirdPlaces} veces 3°');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AcademyProfileSectionTitle(title: 'Fase regular registrada'),
        if (stats.teamEntries > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${AcademyStatsHelpers.formatCount(stats.teamEntries)} participaciones en tabla',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 12,
            ),
          ),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            lines.join('\n'),
            style: GoogleFonts.oswald(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryStatsSection extends StatelessWidget {
  const _CategoryStatsSection({
    required this.stats,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<AcademyCategoryStats> stats;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final effectiveKey = selectedKey ?? '__all__';
    AcademyCategoryStats? selected;
    if (effectiveKey != '__all__') {
      for (final item in stats) {
        if (item.category.key == effectiveKey || item.category.id == effectiveKey) {
          selected = item;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AcademyProfileSectionTitle(title: 'Por categoría'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                label: 'Todas',
                selected: effectiveKey == '__all__',
                onTap: () => onSelected(null),
              ),
              for (final item in stats)
                _CategoryChip(
                  label: item.category.name,
                  selected: item.category.key == effectiveKey ||
                      item.category.id == effectiveKey,
                  onTap: () => onSelected(
                    item.category.key.isNotEmpty
                        ? item.category.key
                        : item.category.id,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (selected == null)
          _CategoryOverviewList(stats: stats)
        else
          _CategoryDetailCard(stat: selected),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? AppTheme.brandTeal.withValues(alpha: 0.15)
            : AppTheme.navySurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppTheme.brandTeal.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? AppTheme.brandTeal : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryOverviewList extends StatelessWidget {
  const _CategoryOverviewList({required this.stats});

  final List<AcademyCategoryStats> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: stats.map((item) {
        final played = AcademyStatsHelpers.effectivePlayed(item.record);
        final pct = AcademyStatsHelpers.formatWinPctPercent(
          item.record.winPctPercent,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.navySurface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.category.name,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  [
                    if (played > 0) '${played} PJ',
                    if (item.record.wins > 0 || item.record.losses > 0)
                      '${item.record.wins} G · ${item.record.losses} P',
                    if (pct.isNotEmpty) pct,
                  ].join('  '),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryDetailCard extends StatelessWidget {
  const _CategoryDetailCard({required this.stat});

  final AcademyCategoryStats stat;

  @override
  Widget build(BuildContext context) {
    final record = stat.record;
    final played = AcademyStatsHelpers.effectivePlayed(record);
    final winPct = AcademyStatsHelpers.formatWinPctPercent(record.winPctPercent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.category.name.toUpperCase(),
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (played > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${AcademyStatsHelpers.formatCount(played)} PJ',
              style: GoogleFonts.oswald(
                color: AppTheme.brandTeal,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${AcademyStatsHelpers.formatCount(record.wins)} G · ${AcademyStatsHelpers.formatCount(record.losses)} P',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (winPct.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              winPct,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _StatMini(
                label: 'PF',
                value: AcademyStatsHelpers.formatCount(record.pointsFor),
              ),
              _StatMini(
                label: 'PC',
                value: AcademyStatsHelpers.formatCount(record.pointsAgainst),
              ),
              _StatMini(
                label: 'DIF',
                value: AcademyStatsHelpers.formatDiff(record.pointDiff),
                highlight: record.pointDiff > 0,
              ),
            ],
          ),
          if (stat.championships > 0 ||
              stat.runnerUps > 0 ||
              stat.finals > 0) ...[
            const SizedBox(height: 14),
            if (stat.championships > 0)
              Text(
                '${stat.championships} campeonato${stat.championships == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  color: AppTheme.brandTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (stat.runnerUps > 0)
              Text(
                '${stat.runnerUps} subcampeonato${stat.runnerUps == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (stat.finals > 0)
              Text(
                '${stat.finals} final${stat.finals == 1 ? '' : 'es'}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _YearStatsSection extends StatelessWidget {
  const _YearStatsSection({required this.yearStats});

  final List<AcademyYearStats> yearStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AcademyProfileSectionTitle(title: 'Por año'),
        const SizedBox(height: 14),
        for (final item in yearStats)
          if (AcademyStatsHelpers.hasRecordActivity(item.record) ||
              item.championships > 0 ||
              item.tournaments > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _YearStatsRow(item: item),
            ),
      ],
    );
  }
}

class _YearStatsRow extends StatelessWidget {
  const _YearStatsRow({required this.item});

  final AcademyYearStats item;

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    final played = AcademyStatsHelpers.effectivePlayed(record);
    final lineParts = <String>[];
    if (played > 0) {
      lineParts.add('${AcademyStatsHelpers.formatCount(played)} PJ');
    }
    if (record.wins > 0 || record.losses > 0) {
      lineParts.add('${record.wins} G');
      lineParts.add('${record.losses} P');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            item.year,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lineParts.isNotEmpty)
                Text(
                  lineParts.join(' · '),
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (item.championships > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${item.championships} campeonato${item.championships == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    color: AppTheme.brandTeal.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (item.tournaments > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${item.tournaments} torneo${item.tournaments == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
