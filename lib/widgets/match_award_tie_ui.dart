import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/match_helpers.dart';
import 'match_award_media.dart';

/// Chip y fotos superpuestas para reconocimientos empatados.
class MatchAwardTiePhotoStack extends StatelessWidget {
  const MatchAwardTiePhotoStack({
    super.key,
    required this.primaryPlayer,
    required this.tiedPlayers,
    required this.teamColor,
    this.mainSize = 72,
    this.miniSize = 28,
    this.resolveMediaUrl,
    this.useSpotlightPhoto = false,
  });

  final Map<String, dynamic> primaryPlayer;
  final List<Map<String, dynamic>> tiedPlayers;
  final Color teamColor;
  final double mainSize;
  final double miniSize;
  final String Function(String)? resolveMediaUrl;
  final bool useSpotlightPhoto;

  bool get hasTie => tiedPlayers.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasTie) {
      return MatchAwardPlayerPhoto(
        player: primaryPlayer,
        teamColor: teamColor,
        size: mainSize,
        resolveMediaUrl: resolveMediaUrl ?? MatchHelpers.resolveMediaUrl,
        useSpotlightPhoto: useSpotlightPhoto,
      );
    }

    final primaryId = _entityId(primaryPlayer);
    Map<String, dynamic>? secondPlayer;
    for (final tied in tiedPlayers) {
      if (_entityId(tied) != primaryId) {
        secondPlayer = tied;
        break;
      }
    }
    secondPlayer ??= tiedPlayers.isNotEmpty ? tiedPlayers.first : null;

    final uniqueCount = _uniqueCount(primaryPlayer, tiedPlayers);
    final extraBeyondTwo = math.max(0, uniqueCount - 2);

    return SizedBox(
      width: mainSize + 10,
      height: mainSize + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: MatchAwardPlayerPhoto(
              player: primaryPlayer,
              teamColor: teamColor,
              size: mainSize,
              resolveMediaUrl: resolveMediaUrl ?? MatchHelpers.resolveMediaUrl,
              useSpotlightPhoto: useSpotlightPhoto,
            ),
          ),
          if (secondPlayer != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F172A),
                        width: 2,
                      ),
                    ),
                    child: MatchAwardPlayerPhoto(
                      player: secondPlayer,
                      teamColor: teamColor,
                      size: miniSize,
                      resolveMediaUrl:
                          resolveMediaUrl ?? MatchHelpers.resolveMediaUrl,
                      useSpotlightPhoto: useSpotlightPhoto,
                    ),
                  ),
                  if (extraBeyondTwo > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '+$extraBeyondTwo',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _uniqueCount(
    Map<String, dynamic> primary,
    List<Map<String, dynamic>> tied,
  ) {
    final ids = <String>{};
    final primaryId = _entityId(primary);
    if (primaryId.isNotEmpty) ids.add(primaryId);
    for (final p in tied) {
      final id = _entityId(p);
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.length;
  }

  String _entityId(Map<String, dynamic> entity) {
    return (entity['_id'] ?? entity['id'] ?? '').toString().trim();
  }
}

class MatchAwardTieChip extends StatelessWidget {
  const MatchAwardTieChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        'EMPATE',
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 7,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

String matchAwardTiedPlayersLabel(List<Map<String, dynamic>> tiedPlayers) {
  if (tiedPlayers.isEmpty) return '';
  if (tiedPlayers.length == 1) return '+1 JUGADOR EMPATADO';
  return '+${tiedPlayers.length} JUGADORES EMPATADOS';
}
