import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/category_palette.dart';
import '../../utils/match_helpers.dart';
import 'related_players_avatars.dart';

enum MatchCardLayout { carousel, list }

class NextBattleCard extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myAcademyName;
  final String? academyId;
  final VoidCallback? onTap;
  final String Function(String)? resolveMediaUrl;
  final MatchCardLayout layout;
  final bool? forcedIsHome;
  final EdgeInsetsGeometry? cardMargin;
  final bool showLiveTicker;

  const NextBattleCard({
    Key? key,
    required this.match,
    required this.myAcademyName,
    this.academyId,
    this.onTap,
    this.resolveMediaUrl,
    this.layout = MatchCardLayout.carousel,
    this.forcedIsHome,
    this.cardMargin,
    this.showLiveTicker = true,
  }) : super(key: key);

  @override
  State<NextBattleCard> createState() => _NextBattleCardState();
}

class _NextBattleCardState extends State<NextBattleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tickerTimer?.cancel();
    super.dispose();
  }

  // --- LOGIC PARA TICKER DE ACCIONES ---
  String? _lastSeenActionId;
  bool _showTicker = false;
  Timer? _tickerTimer;

  void _checkNewAction() {
    if (!widget.showLiveTicker) return;
    final action = widget.match['lastAction'];
    if (action != null && action is Map) {
      final id = (action['_id'] ?? action['id'])?.toString();
      if (id != null && id != _lastSeenActionId) {
        _lastSeenActionId = id;

        // Disparamos el ticker
        _tickerTimer?.cancel();
        setState(() => _showTicker = true);

        // Se oculta tras 15 segundos de gloria
        _tickerTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _showTicker = false);
        });
      }
    }
  }

  @override
  void didUpdateWidget(NextBattleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkNewAction();
  }

  String _getTimeUntil(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final matchDate = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);
      final mDate = DateTime(matchDate.year, matchDate.month, matchDate.day);

      final diffDays = mDate.difference(today).inDays;

      if (matchDate.isBefore(now)) return "EN CURSO";
      if (diffDays == 0) return "HOY";
      if (diffDays == 1) return "MAÑANA";
      return "EN $diffDays DÍAS";
    } catch (_) {
      return "";
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "--:--";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "--:--";
    }
  }

  String _formatDateDay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = [
        "ENE",
        "FEB",
        "MAR",
        "ABR",
        "MAY",
        "JUN",
        "JUL",
        "AGO",
        "SEP",
        "OCT",
        "NOV",
        "DIC",
      ];
      return "${date.day} ${months[date.month - 1]}";
    } catch (_) {
      return "";
    }
  }

  Widget _buildAnimatedPoints(dynamic points) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final inAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, -1.2),
              end: const Offset(0.0, 0.0),
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            );

        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.2),
          end: const Offset(0.0, 0.0),
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInBack));

        if (child.key == ValueKey(points)) {
          return ClipRect(
            child: SlideTransition(
              position: inAnimation,
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        } else {
          return ClipRect(
            child: SlideTransition(
              position: outAnimation,
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      },
      child: Text(
        "$points",
        key: ValueKey(points),
        style: GoogleFonts.oswald(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  bool _checkPossession(
    Map<String, dynamic> team,
    dynamic possessionId, {
    required bool isHome,
    required Map<String, dynamic> match,
  }) {
    if (possessionId == null) return false;
    final String pId = possessionId.toString().trim();
    if (pId.isEmpty || pId == 'null') return false;

    // 1. Comparación Directa (Team ID)
    final String tId = (team['_id'] ?? team['id'] ?? team['teamId'] ?? '')
        .toString()
        .trim();
    if (tId.isNotEmpty && tId == pId) return true;

    // 2. Comparación de Academy ID (Si fuera el caso)
    final academyId = (team['academy'] is Map)
        ? (team['academy']['id'] ?? team['academy']['_id'])?.toString().trim()
        : team['academyId']?.toString().trim();
    if (academyId != null && academyId.isNotEmpty && academyId == pId)
      return true;

    // 3. Comparación por campos planos en el match (homeId / visitorId)
    final String flatHomeId =
        (match['homeId'] ?? match['idHome'] ?? match['home_id'] ?? '')
            .toString()
            .trim();
    final String flatVisitorId =
        (match['visitorId'] ?? match['idVisitor'] ?? match['visitor_id'] ?? '')
            .toString()
            .trim();

    if (isHome && flatHomeId.isNotEmpty && flatHomeId == pId) return true;
    if (!isHome && flatVisitorId.isNotEmpty && flatVisitorId == pId)
      return true;

    return false;
  }

  String? _getMatchPeriod(Map<String, dynamic> match) {
    // Intentamos obtener el periodo de varios campos comunes en el backend
    final val =
        match['currentHalf'] ??
        match['half'] ??
        match['periodo'] ??
        match['tiempo'];
    
    final s = (val ?? "").toString().trim().toUpperCase();
    
    // Si no hay valor, o es "0" o es "OT" (pero no estamos en overtime real/status),
    // devolvemos "1" para que se vea como 1T por defecto.
    if (s.isEmpty || s == "0" || s == "NULL" || s == "OT") {
      return "1";
    }

    return s;
  }

  Widget _buildTeamLogo(
    String name,
    String logo, {
    bool hasPossession = false,
    Color? liveColor,
    String? sideLabel,
    bool compact = false,
  }) {
    final possessionColor = liveColor ?? AppTheme.brandTeal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.navyPrimary,
                  border: Border.all(
                    color: hasPossession
                        ? possessionColor.withAlpha(210)
                        : Colors.white.withAlpha(28),
                    width: hasPossession ? 2.2 : 1.2,
                  ),
                  boxShadow: hasPossession
                      ? [
                          BoxShadow(
                            color: possessionColor.withAlpha(45),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: (logo.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: widget.resolveMediaUrl?.call(logo) ?? logo,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) =>
                              Container(color: Colors.black26),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.textSecondary,
                            size: 28,
                          ),
                        )
                      : Icon(
                          Icons.shield,
                          size: 24,
                          color: Colors.white.withAlpha(20),
                        ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        if (sideLabel != null) ...[
          Text(
            sideLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.oswald(
              fontSize: compact ? 6 : 7,
              fontWeight: FontWeight.w600,
              color: sideLabel == 'LOCAL'
                  ? AppTheme.brandTeal.withAlpha(105)
                  : const Color(0xFF7C4DFF).withAlpha(105),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: compact ? 1 : 2),
        ],
        Text(
          name.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.oswald(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary.withAlpha(195),
          ),
        ),
      ],
    );
  }

  String _fieldLabel(Map<String, dynamic> match) =>
      MatchHelpers.fieldLabel(match);

  String _sedeLabel(
    Map<String, dynamic> match,
    Map<String, dynamic> tournament,
  ) =>
      MatchHelpers.sedeName(match, tournament: tournament);

  TextStyle _metaMutedStyle({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: Colors.white.withAlpha(205),
    );
  }

  Widget _buildStatusLabel(String label, Map<String, dynamic> match) {
    if (label.isEmpty) return const SizedBox.shrink();

    final Color color;
    if (MatchHelpers.isLive(match) || MatchHelpers.isOvertime(match)) {
      color = const Color(0xFFEF4444);
    } else if (MatchHelpers.isFinished(match)) {
      color = Colors.white.withAlpha(120);
    } else if (MatchHelpers.isScheduledStatus(match)) {
      color = Colors.white.withAlpha(215);
    } else {
      color = Colors.white.withAlpha(180);
    }

    return Text(
      label,
      style: GoogleFonts.oswald(
        fontSize: label == 'EN VIVO' ? 9 : 8,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFinishedScoreRow(
    Map<String, dynamic> match,
    Map<String, dynamic> home,
    Map<String, dynamic> visitor,
  ) {
    final homePts = MatchHelpers.teamPoints(match, home: true) ?? 0;
    final visitorPts = MatchHelpers.teamPoints(match, home: false) ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$homePts',
          style: GoogleFonts.oswald(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(220),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '-',
            style: GoogleFonts.oswald(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ),
        Text(
          '$visitorPts',
          style: GoogleFonts.oswald(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white.withAlpha(220),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final home = (match['home'] is Map)
        ? (match['home'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final visitor = (match['visitor'] is Map)
        ? (match['visitor'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final tournamentData = match['tournament'];
    final tournament = (tournamentData is Map)
        ? (tournamentData as Map<String, dynamic>)
        : <String, dynamic>{};

    final dateStr = match['date']?.toString() ?? "";
    final timeStr = _getTimeUntil(dateStr);
    final hourStr = _formatTime(dateStr);
    final dayStr = _formatDateDay(dateStr);

    final bool isOvertime = MatchHelpers.isOvertime(match);
    final bool isLive = MatchHelpers.isLive(match) || isOvertime;
    final bool isFinished = MatchHelpers.isFinished(match);
    final Color liveColor = isOvertime ? const Color(0xFFFF8800) : AppTheme.brandTeal;
    final bool isListLayout = widget.layout == MatchCardLayout.list;
    final bool compactCarousel = !isListLayout;
    final bool showMarcador = isLive || (isListLayout && isFinished);

    final rawCategory = (MatchHelpers.categoryName(match) ?? '').trim();
    final categoryPaletteKey = rawCategory.isEmpty ? '' : rawCategory;
    final categoryFallbackLabel = rawCategory.isEmpty
        ? 'CATEGORÍA TBD'
        : CategoryPalette.shortName(rawCategory);
    final fieldLabel = _fieldLabel(match);
    final sedeLabel = _sedeLabel(match, tournament);
    final statusLabel = MatchHelpers.statusDisplayLabel(match);
    final relatedAvatarEntries =
        MatchHelpers.relatedPlayersAvatarEntries(match);
    final relatedAvatars = RelatedPlayersAvatars(
      match: match,
      resolveMediaUrl: widget.resolveMediaUrl,
      size: isListLayout ? 26 : 24,
    );

    return Container(
      margin: widget.cardMargin ??
          EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compactCarousel ? 4 : 8,
          ),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive
              ? liveColor
              : Colors.white24.withAlpha(150),
          width: isLive ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? liveColor.withAlpha(isOvertime ? 60 : 40)
                : Colors.black.withAlpha(60),
            blurRadius: isLive ? (isOvertime ? 25 : 20) : 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                // Subtle Ambient Light
                Positioned(
                  top: -60,
                  left: -60,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          isLive
                              ? liveColor.withAlpha(isOvertime ? 45 : 30)
                              : AppTheme.brandTeal.withAlpha(15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                Column(
                  mainAxisSize: MainAxisSize.min, // Compacto
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        compactCarousel ? 6 : 8,
                        16,
                        0,
                      ),
                      child: isListLayout
                          ? Row(
                              children: [
                                Expanded(
                                  child: CategoryPalette.buildDarkCardLabel(
                                    categoryPaletteKey,
                                    fontSize: 16,
                                    fallbackLabel: categoryFallbackLabel,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    fieldLabel,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _metaMutedStyle(fontSize: 10),
                                  ),
                                ),
                                Expanded(
                                  child: relatedAvatars,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: CategoryPalette.buildDarkCardLabel(
                                    categoryPaletteKey,
                                    fontSize: 18,
                                    fallbackLabel: categoryFallbackLabel,
                                  ),
                                ),
                                if (relatedAvatarEntries.isNotEmpty) ...[
                                  relatedAvatars,
                                  const SizedBox(width: 8),
                                ],
                                _buildStatusLabel(statusLabel, match),
                              ],
                            ),
                    ),

                    SizedBox(height: compactCarousel ? 6 : 8),

                    // --- CENTER: LOGOS & TIME HUB ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Columna Equipo Izquierda
                          Expanded(
                            flex: 3,
                            child: _buildTeamLogo(
                              (home['name'] ?? "TBD").toString(),
                              (home['logo'] ?? "").toString(),
                              liveColor: isLive ? liveColor : null,
                              sideLabel: 'LOCAL',
                              compact: compactCarousel,
                              hasPossession: _checkPossession(
                                home,
                                match['possessionTeamId'],
                                isHome: true,
                                match: match,
                              ),
                            ),
                          ),

                          // TIME HUB O MARCADOR
                          Expanded(
                            flex: 4,
                            child: showMarcador
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLive)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                          _buildAnimatedPoints(
                                            MatchHelpers.teamPoints(
                                              match,
                                              home: true,
                                            ) ??
                                                0,
                                          ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                '-',
                                                style: GoogleFonts.oswald(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white.withAlpha(
                                                    180,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          _buildAnimatedPoints(
                                            MatchHelpers.teamPoints(
                                              match,
                                              home: false,
                                            ) ??
                                                0,
                                          ),
                                          ],
                                        )
                                      else
                                        _buildFinishedScoreRow(
                                          match,
                                          home,
                                          visitor,
                                        ),
                                      if (isLive) ...[
                                        const SizedBox(height: 4),
                                        FadeTransition(
                                          opacity: _pulseAnimation,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOvertime
                                                  ? liveColor
                                                  : const Color(0xFFFF0000),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isOvertime
                                                          ? liveColor
                                                          : const Color(
                                                            0xFFFF0000,
                                                          ))
                                                      .withAlpha(150),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isOvertime
                                                      ? 'SERIES EXTRA ⚡'
                                                      : _getMatchPeriod(
                                                                widget.match,
                                                              ) !=
                                                              null
                                                          ? 'EN VIVO • ${_getMatchPeriod(widget.match)}T'
                                                          : 'EN VIVO',
                                                  style: GoogleFonts.oswald(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else if (isFinished && isListLayout) ...[
                                        const SizedBox(height: 4),
                                        _buildStatusLabel(statusLabel, match),
                                      ],
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isListLayout) ...[
                                        _buildStatusLabel(statusLabel, match),
                                        if (statusLabel.isNotEmpty)
                                          const SizedBox(height: 4),
                                        if (hourStr != '--:--')
                                          Text(
                                            '$hourStr hrs.'.toUpperCase(),
                                            style: _metaMutedStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                      ] else ...[
                                        if (timeStr.isNotEmpty)
                                          Text(
                                            timeStr.toUpperCase(),
                                            style: _metaMutedStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        Text(
                                          dayStr.toUpperCase(),
                                          style: GoogleFonts.shareTech(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '$hourStr hrs.'.toUpperCase(),
                                          style: _metaMutedStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),

                          // Columna Equipo Derecha
                          Expanded(
                            flex: 3,
                            child: _buildTeamLogo(
                              (visitor['name'] ?? "TBD").toString(),
                              (visitor['logo'] ?? "").toString(),
                              liveColor: isLive ? liveColor : null,
                              sideLabel: 'VISITA',
                              compact: compactCarousel,
                              hasPossession: _checkPossession(
                                visitor,
                                match['possessionTeamId'],
                                isHome: false,
                                match: match,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- FOOTER ---
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: compactCarousel ? 5 : 6,
                      ),
                      decoration: isListLayout
                          ? null
                          : BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white24.withAlpha(50),
                                  width: 0.8,
                                ),
                              ),
                            ),
                      child: isListLayout
                          ? Center(
                              child: Text(
                                sedeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.shareTech(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary.withAlpha(110),
                                ),
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 600),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.0, 0.5),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: _showTicker &&
                                      widget.showLiveTicker &&
                                      widget.match['lastAction'] != null
                                  ? _buildLiveActionTicker(
                                      widget.match['lastAction'],
                                    )
                                  : Row(
                                      key: const ValueKey('normal_footer'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          fieldLabel,
                                          style: _metaMutedStyle(fontSize: 10),
                                        ),
                                        Expanded(
                                          child: Text(
                                            sedeLabel,
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.shareTech(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveActionTicker(Map<String, dynamic> action) {
    final isSystem = (action['type']?.toString().toUpperCase() == 'SISTEMA' ||
        action['clave']?.toString().toUpperCase() == 'SISTEMA' ||
        action['clave']?.toString().toLowerCase() == 'possession');

    String teamName = (action['team']?['name'] ?? '').toString().toUpperCase();
    if (teamName == 'SISTEMA') teamName = "";

    String name = (action['name'] ?? 'ACCIÓN').toString().toUpperCase();
    if (isSystem) {
      name = name.replaceAll('SISTEMA:', '').replaceAll('SISTEMA', '').trim();
      if (name.isEmpty &&
          action['clave']?.toString().toLowerCase() == 'possession') {
        name = "CAMBIO DE POSESIÓN";
      } else if (name.isEmpty) {
        name = "ACCIÓN DE JUEGO";
      }
    }

    final points = action['points'];

    String formatPlayer(dynamic player) {
      if (player == null) return "";
      final pName = (player['name'] ?? '').toString().toUpperCase();
      final pNum = player['number']?.toString() ?? '';
      return pNum.isNotEmpty ? "$pName (#$pNum)" : pName;
    }

    final passer = action['playerPass'];
    final catcher = action['playerCatch'];
    final soloPlayer = action['player'];

    String playerDetail = "";
    if (passer != null && catcher != null) {
      playerDetail = "QB: ${formatPlayer(passer)} ➔ ${formatPlayer(catcher)}";
    } else if (soloPlayer != null) {
      playerDetail = formatPlayer(soloPlayer);
    }

    return Column(
      key: ValueKey('action_${action['_id'] ?? action['id'] ?? DateTime.now().millisecondsSinceEpoch}'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fila 1: Resumen de Acción (Centrada)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "EN ESTE MOMENTO:",
                style: GoogleFonts.oswald(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "${teamName.isNotEmpty ? '$teamName • ' : ''}🔥 $name ${points != null && points != 0 ? '(+$points PTS)' : ''}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        
        // Fila 2: Jugadores (Centrada si existen)
        if (playerDetail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              playerDetail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(220),
                letterSpacing: 0.3,
              ),
            ),
          ),
      ],
    );
  }
}
