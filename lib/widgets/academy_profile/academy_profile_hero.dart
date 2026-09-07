import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../models/academy_profile_models.dart';
import '../../utils/academy_profile_helpers.dart';
import '../../utils/match_helpers.dart';
import 'academy_profile_sections.dart';

class AcademyProfileHero extends StatelessWidget {
  const AcademyProfileHero({
    super.key,
    required this.academy,
    required this.summary,
  });

  final AcademyProfile academy;
  final AcademySummary summary;

  static const double expandedHeight = 318;

  @override
  Widget build(BuildContext context) {
    final coverUrl = _mediaUrl(academy.coverPhoto);
    final logoUrl = _mediaUrl(academy.logo);
    final trajectoryYear = summary.registeredSinceYearLabel();
    final description = academy.description.trim();
    final showShortDescription =
        AcademyProfileHelpers.isShortDescription(description);

    return Stack(
      fit: StackFit.expand,
      children: [
        _CoverBackground(coverUrl: coverUrl),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.navyPrimary.withValues(alpha: 0.35),
                AppTheme.navyPrimary.withValues(alpha: 0.62),
                AppTheme.navyPrimary.withValues(alpha: 0.9),
                AppTheme.navyPrimary,
              ],
              stops: const [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              children: [
                const SizedBox(height: 36),
                Semantics(
                  label: academy.name,
                  child: _AcademyLogo(logoUrl: logoUrl, name: academy.name),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  label: academy.name,
                  child: Text(
                    academy.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1.08,
                    ),
                  ),
                ),
                if (trajectoryYear != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Trayectoria registrada desde $trajectoryYear',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.brandTeal.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (showShortDescription) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _mediaUrl(String? raw) {
    if (raw == null) return '';
    return MatchHelpers.resolveMediaUrl(raw);
  }
}

class AcademyProfileDescriptionStrip extends StatelessWidget {
  const AcademyProfileDescriptionStrip({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final text = description.trim();
    if (text.isEmpty ||
        AcademyProfileHelpers.isShortDescription(text)) {
      return const SizedBox.shrink();
    }

    return AcademyProfileFadeIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            height: 1.55,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({required this.coverUrl});

  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    if (coverUrl.isEmpty) {
      return const _CoverFallback();
    }

    return CachedNetworkImage(
      imageUrl: coverUrl,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _CoverFallback(),
      placeholder: (_, __) => ColoredBox(color: AppTheme.navySurface),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF152238),
            AppTheme.navyElevated,
            AppTheme.navyPrimary,
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 28, right: 20),
          child: Icon(
            Icons.sports_football_outlined,
            size: 140,
            color: Colors.white.withValues(alpha: 0.035),
          ),
        ),
      ),
    );
  }
}

class _AcademyLogo extends StatelessWidget {
  const _AcademyLogo({required this.logoUrl, required this.name});

  final String logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return SizedBox(
      width: 100,
      height: 100,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) =>
                  _InitialsFallback(initials: initials),
              placeholder: (_, __) => _InitialsFallback(initials: initials),
            )
          : _InitialsFallback(initials: initials),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'A';
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.navyElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.oswald(
            color: AppTheme.brandTeal,
            fontSize: 36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
