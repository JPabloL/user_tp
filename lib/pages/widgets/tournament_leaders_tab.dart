import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class TournamentLeadersTab extends StatefulWidget {
  final ApiService api;
  final String tournamentId;
  final List<dynamic> categories;
  final String Function(String) resolveMediaUrl;

  const TournamentLeadersTab({
    Key? key,
    required this.api,
    required this.tournamentId,
    required this.categories,
    required this.resolveMediaUrl,
  }) : super(key: key);

  @override
  State<TournamentLeadersTab> createState() => _TournamentLeadersTabState();
}

class _TournamentLeadersTabState extends State<TournamentLeadersTab> with TickerProviderStateMixin {
  // --- Constants (Premium Sport Tech) ---
  static const Color brandBg = Color(0xFF0F172A);
  static const Color brandSurface = Color(0xFF1E293B);
  static const Color brandPrimary = Color(0xFF2DD4BF);
  static const Color textMuted = Colors.white54;
  
  static const Color goldMetal = Color(0xFFFFD700);
  static const Color silverMetal = Color(0xFFF5F5F5);
  static const Color bronzeMetal = Color(0xFFCD7F32);

  // --- State ---
  bool _isLoading = true;
  Map<String, dynamic>? _leaderboardData;
  String _selectedCategory = '';
  String _selectedGroup = 'Todos';
  String _selectedMetric = 'pases'; // pases, puntos_ofensa, sacks, inter

  // --- Animation Controllers ---
  late AnimationController _shimmerController;
  late AnimationController _transitionController;

  final Map<String, Map<String, String>> _metrics = {
    'pases': {'label': 'PASES', 'unit': 'Pases', 'icon': 'swap_horiz'},
    'puntos_ofensa': {'label': 'PUNTOS', 'unit': 'Pts', 'icon': 'bolt'},
    'sacks': {'label': 'SACKS', 'unit': 'Scks', 'icon': 'shield'},
    'inter': {'label': 'INTERCEPCIONES', 'unit': 'Int', 'icon': 'track_changes'},
  };

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    _initFilters();
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _initFilters() {
    if (widget.categories.isNotEmpty) {
      final firstCat = widget.categories.first;
      _selectedCategory = (firstCat is Map ? firstCat['name'] : firstCat)?.toString() ?? '';
    }
  }

  List<String> _getGroupsForCurrentCategory() {
    final cat = widget.categories.firstWhere(
      (c) {
        final name = (c is Map ? c['name'] : c)?.toString() ?? '';
        return name == _selectedCategory;
      },
      orElse: () => null,
    );
    if (cat != null && cat is Map && cat['groups'] != null && cat['groups'] is List) {
      final List<String> groups = (cat['groups'] as List).map((e) => e.toString()).toList();
      if (groups.isNotEmpty) {
        return ['Todos', ...groups];
      }
    }
    return ['Todos'];
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    final catFormatted = _selectedCategory.replaceAll(' ', '');
    final groupFormatted = _selectedGroup == 'Todos' ? 'Unique' : _selectedGroup.replaceAll(' ', '');
    final docId = 'leaderboard_${widget.tournamentId}_${catFormatted}_$groupFormatted';

    try {
      final res = await widget.api.post('/get-doc', {'id': docId});
      if (res['status'] == 'ok' && res['doc'] != null) {
        setState(() {
          _leaderboardData = res['doc'];
        });
      } else {
        setState(() {
          _leaderboardData = null;
        });
      }
    } catch (e) {
      setState(() {
        _leaderboardData = null;
      });
    }

    setState(() {
      _isLoading = false;
    });
    _transitionController.forward(from: 0.0);
  }

  void _changeCategory(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      _selectedGroup = 'Todos';
    });
    _fetchLeaderboard();
  }

  void _changeGroup(String newGroup) {
    setState(() {
      _selectedGroup = newGroup;
    });
    _fetchLeaderboard();
  }

  void _changeMetric(String newMetric) {
    if (_selectedMetric == newMetric) return;
    _transitionController.reverse().then((_) {
      setState(() {
        _selectedMetric = newMetric;
      });
      _transitionController.forward();
    });
  }

  void _onPlayerTap(Map<String, dynamic> player, Map<String, dynamic> team) {
    final pId = (player['_id'] ?? player['id'] ?? '').toString();
    final tId = (team['_id'] ?? team['id'] ?? '').toString();

    if (pId.isNotEmpty && tId.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/player_stat_detail',
        arguments: {'player': player, 'team': team},
      );
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandBg,
      child: Column(
        children: [
          _buildHeroStrip(),
          _buildFiltersBar(),
          _buildMetricSelector(),
          Expanded(
            child: _isLoading 
                ? _buildPremiumLoading() 
                : _buildLeaderboardContent(),
          ),
        ],
      ),
    );
  }

  // 1. Hero Strip
  Widget _buildHeroStrip() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0x142DD4BF), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: Color(0x1A2DD4BF), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LEADERBOARD', style: GoogleFonts.oswald(color: textMuted, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.bold)),
              Text('$_selectedCategory • $_selectedGroup', style: GoogleFonts.inter(color: brandPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x1A2DD4BF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x332DD4BF))),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: brandPrimary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('SEASON', style: GoogleFonts.oswald(color: brandPrimary, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 2. Filters
  Widget _buildFiltersBar() {
    final groups = _getGroupsForCurrentCategory();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildFilterModule('CATEGORÍA', _selectedCategory, _showCategoryModal)),
          if (groups.length > 1) ...[
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildFilterModule('GRUPO', _selectedGroup, () => _showGroupModal(groups))),
          ]
        ],
      ),
    );
  }

  Widget _buildFilterModule(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: brandSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(color: textMuted, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.oswald(color: Colors.white, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  // 3. Metric Selector
  Widget _buildMetricSelector() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _metrics.keys.length,
        separatorBuilder: (_,__) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final key = _metrics.keys.elementAt(index);
          final metric = _metrics[key]!;
          final isActive = key == _selectedMetric;
          
          return GestureDetector(
            onTap: () => _changeMetric(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? const Color(0x1F2DD4BF) : const Color(0xFF151B28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isActive ? brandPrimary.withOpacity(0.8) : Colors.white.withOpacity(0.06), width: isActive ? 1.5 : 1),
                boxShadow: isActive ? [BoxShadow(color: brandPrimary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(metric['label']!, style: GoogleFonts.oswald(color: isActive ? Colors.white : textMuted, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
                  if (isActive)
                    Container(margin: const EdgeInsets.only(top: 4), height: 3, width: 24, decoration: BoxDecoration(color: brandPrimary, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 4. Content Area
  Widget _buildLeaderboardContent() {
    if (_leaderboardData == null || _leaderboardData!['stats'] == null) {
      return _buildPremiumEmpty();
    }
    
    final List<dynamic> statsList = _leaderboardData!['stats'][_selectedMetric] ?? [];
    if (statsList.isEmpty) return _buildPremiumEmpty();

    final top3 = statsList.take(3).toList();
    final challengers = statsList.skip(3).toList();

    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return Opacity(
          opacity: _transitionController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _transitionController.value)),
            child: child,
          ),
        );
      },
      child: RefreshIndicator(
        onRefresh: _fetchLeaderboard,
        color: brandPrimary,
        backgroundColor: brandSurface,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            _buildPodiumStage(top3),
            if (challengers.isNotEmpty)
              _buildLeaderStrip(challengers),
          ],
        ),
      ),
    );
  }

  // 5. Podium Stage
  Widget _buildPodiumStage(List<dynamic> top3) {
    if (top3.isEmpty) return const SizedBox();

    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: [Color(0x1A2DD4BF), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          Text('TOP PERFORMERS', style: GoogleFonts.inter(color: textMuted, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (second != null) Expanded(child: _buildPodiumCard(second, 2, silverMetal, 220)),
              if (first != null) Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _buildPodiumCard(first, 1, goldMetal, 280))),
              if (third != null) Expanded(child: _buildPodiumCard(third, 3, bronzeMetal, 200)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(Map<String, dynamic> data, int rank, Color metalColor, double height) {
    final player = data['player'] ?? {};
    final team = data['team'] ?? {};
    final val = data['val']?.toString() ?? '0';
    
    final avatarUrl = widget.resolveMediaUrl(player['thumb']?.toString() ?? '');
    final logoUrl = widget.resolveMediaUrl(team['logo']?.toString() ?? '');
    final name = (player['alias'] ?? player['name'] ?? 'Desconocido').toString().toUpperCase();
    final unit = _metrics[_selectedMetric]!['unit']!.toUpperCase();

    return GestureDetector(
      onTap: () => _onPlayerTap(player, team),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: metalColor.withOpacity(0.3), width: rank == 1 ? 2 : 1),
          boxShadow: [BoxShadow(color: metalColor.withOpacity(0.15), blurRadius: rank == 1 ? 24 : 12, spreadRadius: 2)],
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Radial Glow
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: RadialGradient(center: Alignment.topCenter, radius: 1.0, colors: [metalColor.withOpacity(0.2), Colors.transparent]),
                ),
              ),
            ),
            // Avatar
            if (avatarUrl.isNotEmpty)
              Positioned.fill(
                bottom: 40,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(avatarUrl, fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
              )
            else
              Positioned.fill(
                bottom: 40,
                child: Center(child: Icon(Icons.person, size: height * 0.4, color: metalColor.withOpacity(0.5))),
              ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, const Color(0xFF0B1220).withOpacity(0.8), const Color(0xFF0B1220)]),
                ),
              ),
            ),
            // Rank Badge
            Positioned(
              top: -10, left: rank == 1 ? -10 : -5,
              child: Container(
                width: rank == 1 ? 40 : 30, height: rank == 1 ? 40 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: brandSurface, border: Border.all(color: metalColor, width: 2), shape: BoxShape.circle, boxShadow: [BoxShadow(color: metalColor.withOpacity(0.5), blurRadius: 8)]),
                child: Text('#$rank', style: GoogleFonts.oswald(color: metalColor, fontSize: rank == 1 ? 18 : 14, fontWeight: FontWeight.bold)),
              ),
            ),
            // Team Logo Chip
            if (logoUrl.isNotEmpty)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: rank == 1 ? 32 : 24, height: rank == 1 ? 32 : 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24), image: DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)),
                ),
              ),
            // Content Bottom (Glassmorphism effect conceptually)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.72),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(val, style: GoogleFonts.oswald(color: metalColor, fontSize: rank == 1 ? 40 : 28, fontWeight: FontWeight.bold, height: 1.0, shadows: [Shadow(color: metalColor.withOpacity(0.5), blurRadius: 10)])),
                  const SizedBox(height: 4),
                  Text(name, style: GoogleFonts.oswald(color: Colors.white, fontSize: rank == 1 ? 16 : 13), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text('$val $unit', style: GoogleFonts.inter(color: brandPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Telemetry Rows
  Widget _buildLeaderStrip(List<dynamic> challengers) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHALLENGERS · RANK 4-N', style: GoogleFonts.oswald(color: textMuted, fontSize: 11, letterSpacing: 2)),
              Text('${challengers.length} ATHLETES', style: GoogleFonts.inter(color: textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: challengers.length,
            separatorBuilder: (_,__) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
            itemBuilder: (ctx, i) {
              final c = challengers[i];
              final player = c['player'] ?? {};
              final team = c['team'] ?? {};
              final val = c['val']?.toString() ?? '0';
              final avatarUrl = widget.resolveMediaUrl(player['thumb']?.toString() ?? '');
              final logoUrl = widget.resolveMediaUrl(team['logo']?.toString() ?? '');
              final name = (player['alias'] ?? player['name'] ?? 'Desconocido').toString();
              final rank = i + 4;
              final isTopChallenger = rank <= 5;
              final unit = _metrics[_selectedMetric]!['unit']!.toUpperCase();

              return GestureDetector(
                onTap: () => _onPlayerTap(player, team),
                child: Container(
                  height: 68,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xE61E293B), Color(0x990F172A)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: isTopChallenger ? brandPrimary : Colors.transparent, width: 3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Center(child: Text(rank.toString(), style: GoogleFonts.oswald(color: isTopChallenger ? brandPrimary : textMuted, fontSize: 20)))),
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10), image: avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null),
                        child: avatarUrl.isEmpty ? const Icon(Icons.person, color: textMuted) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: GoogleFonts.oswald(color: Colors.white, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (logoUrl.isNotEmpty) ...[
                                  ClipOval(child: Image.network(logoUrl, width: 14, height: 14, fit: BoxFit.cover)),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(child: Text(team['name']?.toString() ?? '', style: GoogleFonts.inter(color: textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(val, style: GoogleFonts.oswald(color: brandPrimary, fontSize: 24, fontWeight: FontWeight.bold, height: 1.0)),
                          Text(unit, style: GoogleFonts.inter(color: textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  // 7. Modals
  void _showCategoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: brandSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: Text('SELECCIONAR CATEGORÍA', style: GoogleFonts.oswald(color: Colors.white, fontSize: 16))),
            Expanded(
              child: ListView.builder(
                itemCount: widget.categories.length,
                itemBuilder: (ctx, i) {
                  final catName = (widget.categories[i] is Map ? widget.categories[i]['name'] : widget.categories[i])?.toString() ?? '';
                  final isSel = catName == _selectedCategory;
                  return ListTile(
                    title: Text(catName, style: GoogleFonts.inter(color: isSel ? brandPrimary : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSel ? const Icon(Icons.check, color: brandPrimary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeCategory(catName);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGroupModal(List<String> groups) {
    showModalBottomSheet(
      context: context,
      backgroundColor: brandSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: Text('SELECCIONAR GRUPO', style: GoogleFonts.oswald(color: Colors.white, fontSize: 16))),
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (ctx, i) {
                  final isSel = groups[i] == _selectedGroup;
                  return ListTile(
                    title: Text(groups[i], style: GoogleFonts.inter(color: isSel ? brandPrimary : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSel ? const Icon(Icons.check, color: brandPrimary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeGroup(groups[i]);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 8. Empty / Loading states
  Widget _buildPremiumEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x1A2DD4BF), boxShadow: [BoxShadow(color: brandPrimary.withOpacity(0.1), blurRadius: 40)]),
            child: const Icon(Icons.emoji_events_outlined, color: brandPrimary, size: 64),
          ),
          const SizedBox(height: 24),
          Text('NO LEADERS YET', style: GoogleFonts.oswald(color: Colors.white, fontSize: 24)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Las estadísticas aparecerán cuando se registren jugadas en este torneo.', style: GoogleFonts.inter(color: textMuted, fontSize: 13), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (ctx, child) {
        final opacity = 0.3 + (_shimmerController.value * 0.4);
        return Opacity(
          opacity: opacity,
          child: Column(
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 80, height: 180, decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 16),
                  Container(width: 110, height: 240, decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 16),
                  Container(width: 80, height: 160, decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(12))),
                ],
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  itemBuilder: (ctx, i) => Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), height: 68, decoration: BoxDecoration(color: brandSurface, borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
