import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../pages/tournament_team_roster_page.dart';
import '../services/api_service.dart';
import '../utils/tournament_participants_helpers.dart';

class TournamentAcademyTeamsSheet extends StatelessWidget {
  const TournamentAcademyTeamsSheet({
    super.key,
    required this.academyId,
    required this.academyName,
    required this.academyLogo,
    required this.teams,
    required this.api,
    required this.resolveMediaUrl,
    this.themeAccent = AppTheme.brandTeal,
    this.onViewAcademy,
  });

  final String academyId;
  final String academyName;
  final String academyLogo;
  final List<Map<String, dynamic>> teams;
  final ApiService api;
  final String Function(String) resolveMediaUrl;
  final Color themeAccent;
  final VoidCallback? onViewAcademy;

  static Future<void> show(
    BuildContext context, {
    required TournamentAcademyVisibleGroup academy,
    required ApiService api,
    required String Function(String) resolveMediaUrl,
    Color themeAccent = AppTheme.brandTeal,
    VoidCallback? onViewAcademy,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1629),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TournamentAcademyTeamsSheet(
        academyId: academy.academyId,
        academyName: academy.academyName,
        academyLogo: academy.academyLogo,
        teams: TournamentParticipantsHelpers.sortedTeams(academy.visibleTeams),
        api: api,
        resolveMediaUrl: resolveMediaUrl,
        themeAccent: themeAccent,
        onViewAcademy: onViewAcademy,
      ),
    );
  }

  void _openTeamDetail(BuildContext context, Map<String, dynamic> team) {
    final teamId = TournamentParticipantsHelpers.resolveTeamId(team);
    if (teamId.isEmpty) return;

    final teamName = TournamentParticipantsHelpers.resolveTeamName(team);
    final categoryLabel = (team['participantCategoryName'] ?? '').toString().trim();
    final categoryShort =
        TournamentParticipantsHelpers.resolveTeamCategoryShortName(team);
    final label = categoryLabel.isNotEmpty ? categoryLabel : categoryShort;

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentTeamRosterPage(
          api: api,
          teamId: teamId,
          previewName: teamName,
          categoryLabel: label,
          resolveMediaUrl: resolveMediaUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final displayName =
        academyName.trim().isNotEmpty ? academyName.trim() : 'Academia';
    final logoUrl = resolveMediaUrl(academyLogo);
    final initials = TournamentParticipantsHelpers.academyInitials(displayName);
    final canViewAcademy = onViewAcademy != null && academyId.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AcademyAvatar(
                  logoUrl: logoUrl,
                  initials: initials,
                  accent: themeAccent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        TournamentParticipantsHelpers.teamCountLabel(teams.length),
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      if (canViewAcademy) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onViewAcademy?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: themeAccent,
                            side: BorderSide(
                              color: themeAccent.withValues(alpha: 0.55),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            'VER ACADEMIA',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: teams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final team = teams[index];
                  final teamName = TournamentParticipantsHelpers.resolveTeamName(team);
                  final teamLogo = resolveMediaUrl(
                    TournamentParticipantsHelpers.resolveTeamLogo(team),
                  );
                  final categoryShort =
                      TournamentParticipantsHelpers.resolveTeamCategoryShortName(team);
                  final teamId = TournamentParticipantsHelpers.resolveTeamId(team);
                  final canOpenTeam = teamId.isNotEmpty;

                  return Semantics(
                    label: canOpenTeam
                        ? 'Ver detalle de $teamName'
                        : teamName,
                    button: canOpenTeam,
                    child: Material(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: canOpenTeam
                            ? () => _openTeamDetail(context, team)
                            : null,
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF334155).withValues(alpha: 0.75),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _TeamAvatar(
                                  logoUrl: teamLogo,
                                  accent: themeAccent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teamName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.oswald(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (categoryShort.isNotEmpty &&
                                          categoryShort != 'TBD') ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          categoryShort,
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (canOpenTeam) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white.withValues(alpha: 0.45),
                                    size: 24,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademyAvatar extends StatelessWidget {
  const _AcademyAvatar({
    required this.logoUrl,
    required this.initials,
    required this.accent,
  });

  final String logoUrl;
  final String initials;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF151D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => _InitialsBox(initials: initials, accent: accent),
              errorWidget: (_, _, _) =>
                  _InitialsBox(initials: initials, accent: accent),
            )
          : _InitialsBox(initials: initials, accent: accent),
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({
    required this.logoUrl,
    required this.accent,
  });

  final String logoUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.navyPrimary,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Icon(
                Icons.shield_outlined,
                size: 20,
                color: accent.withValues(alpha: 0.7),
              ),
            )
          : Icon(
              Icons.shield_outlined,
              size: 20,
              color: accent.withValues(alpha: 0.7),
            ),
    );
  }
}

class _InitialsBox extends StatelessWidget {
  const _InitialsBox({
    required this.initials,
    required this.accent,
  });

  final String initials;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.oswald(
          color: accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
