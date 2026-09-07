import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../utils/tournament_catalog_helpers.dart';

class TournamentCatalogCard extends StatelessWidget {
  const TournamentCatalogCard({
    super.key,
    required this.tournament,
    required this.onTap,
    this.showActiveBadge = false,
  });

  final Map<String, dynamic> tournament;
  final VoidCallback onTap;
  final bool showActiveBadge;

  @override
  Widget build(BuildContext context) {
    final accent = TournamentCatalogHelpers.accentColor(
      tournament,
      AppTheme.brandTeal,
    );
    final coverUrl = (tournament['img'] ?? '').toString();
    final logoUrl = (tournament['logo'] ?? '').toString();
    final leagueLogo = TournamentCatalogHelpers.leagueLogo(tournament);
    final leagueName = TournamentCatalogHelpers.leagueName(tournament);
    final name = (tournament['name'] ?? 'Torneo').toString();
    final subname = (tournament['subname'] ?? '').toString();
    final modalidad = (tournament['modalidad'] ?? '').toString();
    final dateRange = TournamentCatalogHelpers.formatDateRange(tournament);
    final categories = (tournament['resumeCates'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 196,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isNotEmpty)
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => _fallbackBg(accent),
                )
              else
                _fallbackBg(accent),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: accent.withValues(alpha: 0.85)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (leagueLogo.isNotEmpty)
                          _CircleLogo(url: leagueLogo, size: 22, borderColor: accent)
                        else if (logoUrl.isNotEmpty)
                          _CircleLogo(url: logoUrl, size: 22, borderColor: accent),
                        if (leagueLogo.isNotEmpty || logoUrl.isNotEmpty)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            leagueName.isNotEmpty ? leagueName.toUpperCase() : 'LIGA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (showActiveBadge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              'ACTIVO',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF86EFAC),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (modalidad.isNotEmpty)
                      Text(
                        modalidad.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: accent.withValues(alpha: 0.95),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (subname.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (dateRange.isNotEmpty) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              dateRange,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.45),
                          size: 22,
                        ),
                      ],
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        categories,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _fallbackBg(Color accent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.25), const Color(0xFF0F1629)),
            const Color(0xFF070B14),
          ],
        ),
      ),
    );
  }
}

class _CircleLogo extends StatelessWidget {
  const _CircleLogo({
    required this.url,
    required this.size,
    required this.borderColor,
  });

  final String url;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
