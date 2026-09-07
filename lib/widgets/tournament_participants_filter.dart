import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../utils/tournament_participants_helpers.dart';

class TournamentParticipantsCategorySheet extends StatelessWidget {
  const TournamentParticipantsCategorySheet({
    super.key,
    required this.options,
    required this.selectedCategoryKey,
    required this.themeAccent,
    required this.onSelected,
  });

  final List<TournamentCategoryFilterOption> options;
  final String? selectedCategoryKey;
  final Color themeAccent;
  final ValueChanged<String?> onSelected;

  static Future<void> show(
    BuildContext context, {
    required List<TournamentCategoryFilterOption> options,
    required String? selectedCategoryKey,
    required Color themeAccent,
    required ValueChanged<String?> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1629),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TournamentParticipantsCategorySheet(
        options: options,
        selectedCategoryKey: selectedCategoryKey,
        themeAccent: themeAccent,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FILTRAR PARTICIPANTES',
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecciona una categoría',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _CategorySheetTile(
                      title: 'Todas las categorías',
                      subtitle: null,
                      selected: selectedCategoryKey == null,
                      accent: themeAccent,
                      onTap: () {
                        onSelected(null);
                        Navigator.of(context).pop();
                      },
                    ),
                    ...options.map(
                      (option) => _CategorySheetTile(
                        title: option.shortName,
                        subtitle: TournamentParticipantsHelpers
                            .categoryOptionSummary(option),
                        selected: selectedCategoryKey == option.key,
                        accent: themeAccent,
                        onTap: () {
                          onSelected(option.key);
                          Navigator.of(context).pop();
                        },
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
  }
}

class _CategorySheetTile extends StatelessWidget {
  const _CategorySheetTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: subtitle == null
          ? title
          : '$title, $subtitle',
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? accent : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentParticipantsFilterBar extends StatelessWidget {
  const TournamentParticipantsFilterBar({
    super.key,
    required this.selectedCategoryKey,
    required this.availableCategories,
    required this.themeAccent,
    required this.onOpenSheet,
  });

  final String? selectedCategoryKey;
  final List<TournamentCategoryFilterOption> availableCategories;
  final Color themeAccent;
  final VoidCallback onOpenSheet;

  String get _currentLabel {
    if (selectedCategoryKey == null) return 'Todas las categorías';
    for (final option in availableCategories) {
      if (option.key == selectedCategoryKey) return option.shortName;
    }
    return 'Todas las categorías';
  }

  String get _semanticsLabel {
    final current = _currentLabel;
    return 'Filtrar participantes por categoría. Selección actual: $current.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticsLabel,
      button: true,
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenSheet,
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: themeAccent.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentParticipantsSummaryHeader extends StatelessWidget {
  const TournamentParticipantsSummaryHeader({
    super.key,
    required this.summaryText,
  });

  final String summaryText;

  @override
  Widget build(BuildContext context) {
    return Text(
      summaryText,
      style: GoogleFonts.inter(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class TournamentParticipantsFilteredEmptyState extends StatelessWidget {
  const TournamentParticipantsFilteredEmptyState({
    super.key,
    required this.onClearFilter,
  });

  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NO HAY PARTICIPANTES EN ESTA CATEGORÍA',
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba seleccionando otra categoría.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onClearFilter,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.brandTeal,
            ),
            child: Text(
              'VER TODAS LAS CATEGORÍAS',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
