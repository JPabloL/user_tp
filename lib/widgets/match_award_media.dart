import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/match_helpers.dart';

/// Imagen de fondo dominante para cards spotlight (publicPhoto prioritaria).
class MatchAwardSpotlightBackdrop extends StatelessWidget {
  const MatchAwardSpotlightBackdrop({
    super.key,
    required this.player,
    required this.teamColor,
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
    this.imageAlignment = Alignment.topCenter,
  });

  final Map<String, dynamic> player;
  final Color teamColor;
  final String Function(String) resolveMediaUrl;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    final photoUrl = MatchHelpers.playerSpotlightPhotoUrl(player);
    final initials = MatchHelpers.playerInitials(player);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photoUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            alignment: imageAlignment,
            placeholder: (_, _) => MatchAwardSpotlightFallback(
              initials: initials,
              teamColor: teamColor,
            ),
            errorWidget: (_, _, _) => MatchAwardSpotlightFallback(
              initials: initials,
              teamColor: teamColor,
            ),
          )
        else
          MatchAwardSpotlightFallback(
            initials: initials,
            teamColor: teamColor,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                teamColor.withValues(alpha: 0.06),
                teamColor.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0.0, 0.32, 0.62, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.12),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class MatchAwardSpotlightFallback extends StatelessWidget {
  const MatchAwardSpotlightFallback({
    super.key,
    required this.initials,
    required this.teamColor,
    this.fontSize = 56,
  });

  final String initials;
  final Color teamColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.alphaBlend(
        teamColor.withValues(alpha: 0.1),
        const Color(0xFF0B1220),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.oswald(
            color: Colors.white.withValues(alpha: 0.22),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// Fotografía circular del jugador con fallback de iniciales.
class MatchAwardPlayerPhoto extends StatelessWidget {
  const MatchAwardPlayerPhoto({
    super.key,
    required this.player,
    required this.teamColor,
    this.size = 72,
    this.resolveMediaUrl = MatchHelpers.resolveMediaUrl,
    this.useSpotlightPhoto = false,
  });

  final Map<String, dynamic> player;
  final Color teamColor;
  final double size;
  final String Function(String) resolveMediaUrl;
  final bool useSpotlightPhoto;

  @override
  Widget build(BuildContext context) {
    final photoUrl = useSpotlightPhoto
        ? MatchHelpers.playerSpotlightPhotoUrl(player)
        : MatchHelpers.playerPhotoUrl(player);
    final initials = MatchHelpers.playerInitials(player);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: teamColor.withValues(alpha: 0.16),
            blurRadius: 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: teamColor.withValues(alpha: 0.38),
            width: 1.2,
          ),
        ),
        child: ClipOval(
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => MatchAwardPlayerInitials(
                    initials: initials,
                    teamColor: teamColor,
                    fontSize: size * 0.3,
                  ),
                  errorWidget: (_, _, _) => MatchAwardPlayerInitials(
                    initials: initials,
                    teamColor: teamColor,
                    fontSize: size * 0.3,
                  ),
                )
              : MatchAwardPlayerInitials(
                  initials: initials,
                  teamColor: teamColor,
                  fontSize: size * 0.3,
                ),
        ),
      ),
    );
  }
}

class MatchAwardPlayerInitials extends StatelessWidget {
  const MatchAwardPlayerInitials({
    super.key,
    required this.initials,
    required this.teamColor,
    this.fontSize = 22,
  });

  final String initials;
  final Color teamColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.alphaBlend(
        teamColor.withValues(alpha: 0.14),
        const Color(0xFF161F2E),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.oswald(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class MatchAwardTeamLogoChip extends StatelessWidget {
  const MatchAwardTeamLogoChip({
    super.key,
    required this.logoUrl,
    required this.teamColor,
    this.size = 16,
  });

  final String logoUrl;
  final Color teamColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: teamColor.withValues(alpha: 0.12),
        border: Border.all(
          color: teamColor.withValues(alpha: 0.28),
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

String formatAwardTeamLine(String? number, String team) {
  final teamLabel = team.trim();
  if (number != null && teamLabel.isNotEmpty) {
    return '#$number · $teamLabel';
  }
  if (number != null) return '#$number';
  return teamLabel;
}
