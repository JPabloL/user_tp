import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/award_score_format.dart';
import '../utils/match_award_detail_builder.dart';
import '../utils/match_helpers.dart';
import 'match_award_media.dart';

/// Bottom sheet reutilizable de detalle de reconocimientos.
class MatchAwardDetailSheet extends StatelessWidget {
  const MatchAwardDetailSheet({
    super.key,
    required this.payload,
    this.mutedTextColor = const Color(0xFF94A3B8),
    this.surfaceColor = const Color(0xFF1E293B),
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
  });

  final MatchAwardDetailPayload payload;
  final Color mutedTextColor;
  final Color surfaceColor;
  final String Function(String) resolveMediaUrl;

  static Future<void> show(
    BuildContext context, {
    required MatchAwardDetailPayload payload,
    Color mutedTextColor = const Color(0xFF94A3B8),
    Color surfaceColor = const Color(0xFF1E293B),
    String Function(String) resolveMediaUrl = MatchHelpers.resolveMediaUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MatchAwardDetailSheet(
        payload: payload,
        mutedTextColor: mutedTextColor,
        surfaceColor: surfaceColor,
        resolveMediaUrl: resolveMediaUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final displayName = MatchHelpers.playerDisplayName(payload.player);
    final number = MatchHelpers.formatPlayerNumber(payload.player['number']);
    final teamLine = formatAwardTeamLine(number, payload.teamName);
    final isMvp = payload.category == MatchAwardCategory.mvp;

    return Semantics(
      namesRoute: true,
      label: _semanticsLabel(displayName, number),
      child: Container(
        margin: const EdgeInsets.only(top: 48),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: payload.teamColor.withValues(alpha: 0.35)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  payload.sectionLabel,
                  style: GoogleFonts.inter(
                    color: mutedTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      payload.icon,
                      size: 16,
                      color: payload.teamColor.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        payload.title,
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MatchAwardPlayerPhoto(
                      player: payload.player,
                      teamColor: payload.teamColor,
                      size: 70,
                      resolveMediaUrl: resolveMediaUrl,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.oswald(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (teamLine.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (payload.teamLogoUrl.isNotEmpty) ...[
                                  MatchAwardTeamLogoChip(
                                    logoUrl: payload.teamLogoUrl,
                                    teamColor: payload.teamColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    teamLine,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (isMvp) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'RECONOCIMIENTO OFICIAL',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    payload.explanation ?? '',
                    style: GoogleFonts.inter(
                      color: mutedTextColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      formatAwardDisplayScore(payload.score),
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      payload.scoreLabel,
                      style: GoogleFonts.inter(
                        color: mutedTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (payload.breakdown.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'DESGLOSE',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...payload.breakdown.map(_breakdownRow),
                  ],
                  if (payload.explanation != null &&
                      payload.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      payload.explanation!,
                      style: GoogleFonts.inter(
                        color: mutedTextColor,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
                if (payload.allTiedEntries.length > 1) ...[
                  const SizedBox(height: 22),
                  Text(
                    'RECONOCIMIENTO COMPARTIDO',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...payload.allTiedEntries.map(_tiedRow),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(AwardBreakdownRow row) {
    final valueText = row.isBonus
        ? formatAwardBonus(row.value)
        : formatAwardDisplayScore(row.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: row.isTotal
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    valueText,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (row.value > 0 || !row.isBonus)
                      Text(
                        valueText,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (row.detail != null && row.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      row.detail!,
                      style: GoogleFonts.inter(
                        color: mutedTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _tiedRow(TiedPlayerEntry entry) {
    final name = MatchHelpers.playerDisplayName(entry.player);
    final number = MatchHelpers.formatPlayerNumber(entry.player['number']);
    final line = formatAwardTeamLine(number, entry.teamName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          MatchAwardPlayerPhoto(
            player: entry.player,
            teamColor: entry.teamColor,
            size: 36,
            resolveMediaUrl: resolveMediaUrl,
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
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: GoogleFonts.inter(
                      color: mutedTextColor,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatAwardDisplayScore(entry.score),
            style: GoogleFonts.oswald(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _semanticsLabel(String name, String? number) {
    final parts = <String>[payload.title];
    if (name.isNotEmpty) parts.add(name);
    if (number != null) parts.add('número $number');
    if (payload.teamName.isNotEmpty) parts.add('de ${payload.teamName}');
    if (payload.category != MatchAwardCategory.mvp) {
      parts.add(
        '${formatAwardDisplayScore(payload.score)} ${payload.scoreLabel.toLowerCase()}',
      );
    }
    return parts.join(', ');
  }
}
