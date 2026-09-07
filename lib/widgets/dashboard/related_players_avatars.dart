import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/match_helpers.dart';

/// Avatares de jugadores relacionados al partido (hijos, tutelados, seguidos).
class RelatedPlayersAvatars extends StatelessWidget {
  const RelatedPlayersAvatars({
    super.key,
    required this.match,
    this.resolveMediaUrl,
    this.size = 26,
    this.maxVisible = 4,
    this.alignment = Alignment.centerRight,
  });

  final Map<String, dynamic> match;
  final String Function(String)? resolveMediaUrl;
  final double size;
  final int maxVisible;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final players = MatchHelpers.relatedPlayersAvatarEntries(match);
    if (players.isEmpty) return const SizedBox.shrink();

    final overlap = size * 0.38;
    final visible = players.take(maxVisible).toList();
    final extra = players.length - visible.length;
    final rowWidth =
        size + (visible.length - 1) * (size - overlap) + (extra > 0 ? 14 : 0);

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: rowWidth,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < visible.length; i++)
              Positioned(
                right: i * (size - overlap),
                child: _PlayerAvatar(
                  player: visible[i],
                  size: size,
                  resolveMediaUrl: resolveMediaUrl,
                ),
              ),
            if (extra > 0)
              Positioned(
                right: visible.length * (size - overlap),
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.brandTeal,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.player,
    required this.size,
    this.resolveMediaUrl,
  });

  final Map<String, dynamic> player;
  final double size;
  final String Function(String)? resolveMediaUrl;

  @override
  Widget build(BuildContext context) {
    final rawPhoto = (player['photo'] ?? '').toString().trim();
    final photo = rawPhoto.isEmpty
        ? ''
        : (resolveMediaUrl?.call(rawPhoto) ?? rawPhoto);

    final alias = (player['alias'] ?? '').toString().trim();
    final name = (player['name'] ?? '').toString().trim();
    final label = alias.isNotEmpty ? alias : name;
    final initial =
        label.isNotEmpty ? label.characters.first.toUpperCase() : '?';

    final isFollowed = player['relation']?.toString() == 'followed';
    final borderColor = isFollowed ? AppTheme.brandTeal : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.2),
            color: const Color(0xFF161F2E),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipOval(
            child: photo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF161F2E),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: size * 0.42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: size * 0.42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        if (isFollowed)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.brandTeal, width: 0.8),
              ),
              child: Icon(
                Icons.star,
                color: Colors.yellowAccent,
                size: size * 0.28,
              ),
            ),
          ),
      ],
    );
  }
}
