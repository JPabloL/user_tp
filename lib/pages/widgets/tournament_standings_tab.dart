import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../config/category_palette.dart';

class TournamentStandingsTab extends StatefulWidget {
  final ApiService api;
  final String tournamentId;
  final List<dynamic> categories;
  final String Function(String) resolveMediaUrl;
  final List<dynamic> myTeamsInThisTournament;

  const TournamentStandingsTab({
    Key? key,
    required this.api,
    required this.tournamentId,
    required this.categories,
    required this.resolveMediaUrl,
    this.myTeamsInThisTournament = const [],
  }) : super(key: key);

  @override
  State<TournamentStandingsTab> createState() => _TournamentStandingsTabState();
}

class _TournamentStandingsTabState extends State<TournamentStandingsTab> {
  // Stealth Mode Colors
  static const Color brandBg = Color(0xFF0F172A);
  static const Color brandSurface = Color(0xFF1E293B);
  static const Color brandPrimary = Color(0xFF2DD4BF);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color danger = Color(0xFFF87171);
  static const Color success = Color(0xFF00E676);
  static const Color loss = Color(0xFFFF5252);
  static const Color playoffFinal = Color(0xFFFFAB40);

  bool _isLoadingStandings = true;
  String _errorMessage = '';
  
  String? _selectedCategory;
  String? _selectedGroup; // null means GENERAL
  
  List<dynamic> _cachedStandingsDocs = [];
  List<String?> _availableGroups = [];
  
  List<dynamic> _standingsData = [];
  Map<dynamic, dynamic>? _playoffsData;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      final firstCat = widget.categories.first;
      _selectedCategory = firstCat is Map ? firstCat['name'] : firstCat.toString();
      _loadStandings();
    } else {
      _isLoadingStandings = false;
      _errorMessage = 'No hay categorías configuradas.';
    }
  }

  Future<void> _loadStandings() async {
    if (_selectedCategory == null) return;
    
    setState(() {
      _isLoadingStandings = true;
      _errorMessage = '';
      _cachedStandingsDocs = [];
      _availableGroups = [];
      _standingsData = [];
      _playoffsData = null;
    });

    try {
      final res = await widget.api.postList('/viewNlff', {
        'view': 'tournament',
        'mood': 'standingsByTourCate',
        'search': [widget.tournamentId, _selectedCategory],
      });

      if (!mounted) return;

      setState(() {
        _isLoadingStandings = false;
        _cachedStandingsDocs = res;
        
        // Extraer grupos disponibles
        final Set<String?> groupsSet = {};
        for (var doc in _cachedStandingsDocs) {
          if (doc is Map) {
            final entries = doc['entries'] as List<dynamic>? ?? [];
            final playoffs = doc['playoffs'] is Map ? doc['playoffs'] : null;
            if (entries.isEmpty && playoffs == null) {
              continue;
            }
            final g = doc['group']?.toString();
            groupsSet.add(g == 'null' || g == '' ? null : g);
          }
        }
        
        _availableGroups = groupsSet.toList();
        // Orden alfabético pero null primero
        _availableGroups.sort((a, b) {
          if (a == null) return -1;
          if (b == null) return 1;
          return a.compareTo(b);
        });

        // Selección inicial
        if (_availableGroups.contains(null)) {
          _selectedGroup = null;
        } else if (_availableGroups.isNotEmpty) {
          _selectedGroup = _availableGroups.first;
        }

        _filterGroupData();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStandings = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  void _filterGroupData() {
    _standingsData = [];
    _playoffsData = null;

    for (var doc in _cachedStandingsDocs) {
      if (doc is Map) {
        final g = doc['group']?.toString();
        final docGroup = (g == 'null' || g == '') ? null : g;
        
        if (docGroup == _selectedGroup) {
          _standingsData = doc['entries'] as List<dynamic>? ?? [];
          _playoffsData = doc['playoffs'] is Map ? doc['playoffs'] : null;
          break;
        }
      }
    }
  }

  void _onCategoryChanged(String newCat) {
    if (_selectedCategory == newCat) return;
    setState(() {
      _selectedCategory = newCat;
      _loadStandings();
    });
  }

  void _onGroupChanged(String? newGroup) {
    if (_selectedGroup == newGroup) return;
    setState(() {
      _selectedGroup = newGroup;
      _filterGroupData();
    });
  }

  String _getDivisionLabel(String? groupId) {
    if (groupId == null) return "GENERAL";
    final n = int.tryParse(groupId);
    if (n != null && n > 0 && n <= 26) {
      return "DIVISIÓN ${String.fromCharCode(64 + n)}"; // 1 -> A
    }
    return "DIVISIÓN $groupId";
  }

  String _getSmartTeamName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    final words = clean.split(RegExp(r'\s+'));
    if (words.length > 2) return words[0].toUpperCase();
    return clean.toUpperCase();
  }

  bool _isMyTeam(String? teamId) {
    if (teamId == null || teamId.isEmpty) return false;
    for (var t in widget.myTeamsInThisTournament) {
      if (t is Map) {
        final id = t['_id'] ?? t['id'];
        if (id == teamId) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _getTeamDetailStats(Map<String, dynamic> entry) {
    final List<Map<String, dynamic>> allGames = [];
    final h2hList = entry['h2h'] as List<dynamic>? ?? [];
    
    for (var opp in h2hList) {
      if (opp is Map) {
        final games = opp['games'] as List<dynamic>? ?? [];
        for (var g in games) {
          if (g is Map) {
            allGames.add({
              ...g,
              'opponent_name': opp['opponent_name'],
              'opponent_logo': opp['opponent_logo'],
            });
          }
        }
      }
    }
    
    allGames.sort((a, b) {
      final ja = int.tryParse(a['journey']?.toString() ?? '0') ?? 0;
      final jb = int.tryParse(b['journey']?.toString() ?? '0') ?? 0;
      return ja.compareTo(jb);
    });

    final pj = int.tryParse(entry['pj']?.toString() ?? '') ?? 1;
    final pf = int.tryParse(entry['pf']?.toString() ?? '') ?? 0;
    final pc = int.tryParse(entry['pc']?.toString() ?? '') ?? 0;
    final shutouts = int.tryParse(entry['shutoutsFavor']?.toString() ?? '') ?? 0;

    final avgFor = (pf / pj).toStringAsFixed(1);
    final avgAgainst = (pc / pj).toStringAsFixed(1);

    final streak = entry['streak'] is Map 
      ? entry['streak'] 
      : {'type': '', 'length': 0};

    return {
      'games': allGames,
      'stats': {
        'avgFor': avgFor,
        'avgAgainst': avgAgainst,
        'shutouts': shutouts.toString(),
      },
      'streak': streak,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandBg,
      child: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 100),
        children: [
          _buildSelectorsRow(),
            
          const SizedBox(height: 20),
          
          if (_isLoadingStandings)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: brandPrimary)),
            )
          else if (_standingsData.isEmpty && _playoffsData == null)
            _buildEmptyState()
          else
            _buildContent(),
        ],
      ),
    );
  }

  String _getDivisionShortLabel(String? groupId) {
    if (groupId == null) return "GEN";
    final n = int.tryParse(groupId);
    if (n != null && n > 0 && n <= 26) {
      return String.fromCharCode(64 + n); // 1 -> A, 2 -> B
    }
    return groupId;
  }

  Widget _buildSelectorsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCategorySelector(),
          if (_availableGroups.length > 1)
            _buildDivisionSelectorInline(),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final showArrow = widget.categories.length > 1;
    final catStyle = CategoryPalette.getStyle(_selectedCategory ?? '');
    final catColor = catStyle['base'] ?? Colors.white;

    final textStyle = GoogleFonts.oswald(
      color: catColor,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (_selectedCategory ?? '').toUpperCase(),
          style: textStyle,
        ),
        if (showArrow) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down,
            color: catColor,
            size: 24,
          ),
        ],
      ],
    );

    if (showArrow) {
      return GestureDetector(
        onTap: _showCategorySelectionModal,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }

  void _showCategorySelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SELECCIONA CATEGORÍA',
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: widget.categories.length,
                      itemBuilder: (ctx, idx) {
                        final c = widget.categories[idx];
                        final catName = (c is Map ? c['name'] : c).toString();
                        final isSelected = catName == _selectedCategory;
                        final catStyle = CategoryPalette.getStyle(catName);
                        final catColor = catStyle['base'] ?? brandPrimary;
                        
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _onCategoryChanged(catName);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            color: isSelected ? catColor.withValues(alpha: 0.10) : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    catName.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: isSelected ? catColor : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check, color: catColor, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDivisionSelectorInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'División:',
          style: GoogleFonts.inter(
            color: textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        ..._availableGroups.map((g) {
          final isSelected = g == _selectedGroup;
          final label = _getDivisionShortLabel(g);
          
          return GestureDetector(
            onTap: () => _onGroupChanged(g),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? brandPrimary.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? brandPrimary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : textMuted,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: brandSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: textMuted, size: 30),
            const SizedBox(height: 16),
            Text(
              'Sin datos disponibles',
              style: GoogleFonts.inter(color: textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_playoffsData != null) _buildPlayoffs(),
        if (_standingsData.isNotEmpty) _buildStandingsTable(),
      ],
    );
  }

  Widget _buildPlayoffs() {
    final brackets = _playoffsData?['brackets'] as List<dynamic>? ?? [];
    if (brackets.isEmpty) return const SizedBox.shrink();
    
    final format = (_playoffsData?['format'] ?? 'STANDARD').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32, left: 20, right: 20),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: brandPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PLAYOFFS',
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: brandPrimary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandPrimary.withValues(alpha: 0.40)),
                ),
                child: Text(
                  format.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: brandPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...brackets.map((b) => _buildBracketScroll(b, format)).toList(),
      ],
    );
  }

  Widget _buildBracketScroll(dynamic bracket, String format) {
    if (bracket is! Map) return const SizedBox.shrink();
    final content = bracket['content'] as List<dynamic>? ?? [];
    if (content.isEmpty) return const SizedBox.shrink();
    
    final bracketName = bracket['bracket']?.toString() ?? '';

    // Agrupar por ronda y ordenar
    final Map<String, List<dynamic>> roundsMap = {};
    for (var match in content) {
      if (match is Map) {
        final round = (match['round'] ?? match['type'] ?? 'otro').toString().toLowerCase();
        roundsMap.putIfAbsent(round, () => []).add(match);
      }
    }

    final List<String> roundOrder = ['semifinal', 'final', 'third_place', 'quarterfinal', 'otro'];
    final sortedKeys = roundsMap.keys.toList()..sort((a, b) {
      int idxA = roundOrder.indexOf(a);
      int idxB = roundOrder.indexOf(b);
      if (idxA == -1) idxA = 99;
      if (idxB == -1) idxB = 99;
      return idxA.compareTo(idxB);
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedKeys.asMap().entries.map((entry) {
            final idx = entry.key;
            final roundKey = entry.value;
            final matches = roundsMap[roundKey] ?? [];
            final isLast = idx == sortedKeys.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBracketColumn(roundKey, matches, format, bracketName),
                if (!isLast) _buildBracketConnector(matches.length),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBracketColumn(String roundKey, List<dynamic> matches, String format, String bracketName) {
    String headerTitle = '';
    if (roundKey.contains('semi')) headerTitle = 'SEMIFINALES';
    else if (roundKey == 'final') headerTitle = 'GRAN FINAL';
    else if (roundKey.contains('third')) headerTitle = '3ER LUGAR';
    else headerTitle = roundKey.toUpperCase();

    if (format.toLowerCase() == 'splitranking' && bracketName.isNotEmpty) {
      headerTitle += ' - ${bracketName.toUpperCase()}';
    }

    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: const Border(left: BorderSide(color: brandPrimary, width: 4)),
              gradient: LinearGradient(
                colors: [brandPrimary.withValues(alpha: 0.15), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Text(
              headerTitle,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...matches.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildBracketMatchCard(m, roundKey),
          )),
        ],
      ),
    );
  }

  Widget _buildBracketConnector(int previousMatchesCount) {
    return Container(
      width: 30,
      // Usaremos un truco visual sencillo en vez de CustomPainter complejo por ahora:
      // Línea horizontal centrada
      alignment: Alignment.center,
      child: Container(
        height: 1.5,
        color: Colors.white.withValues(alpha: 0.20),
      ),
    );
  }

  Widget _buildBracketMatchCard(dynamic match, String roundKey) {
    if (match is! Map) return const SizedBox.shrink();
    
    final home = match['home'];
    final visitor = match['visitor'];
    final status = match['gameStatus']?.toString() ?? '';
    final isFinished = status == 'finished';

    final bool isFinalRound = roundKey.contains('final') && !roundKey.contains('semi');
    final Color accentColor = isFinalRound ? playoffFinal : brandPrimary;

    int? getPoints(dynamic teamMap, bool isHome) {
      if (match['score'] is Map) {
        final scoreNode = match['score'];
        final p = isHome ? scoreNode['home'] : scoreNode['visitor'];
        if (p != null) return int.tryParse(p.toString());
      }
      if (teamMap is Map && teamMap['points'] != null) {
        return int.tryParse(teamMap['points'].toString());
      }
      return null;
    }

    final homePoints = getPoints(home, true);
    final visitorPoints = getPoints(visitor, false);

    bool homeWon = false;
    bool visitorWon = false;
    if (isFinished && homePoints != null && visitorPoints != null) {
      if (homePoints > visitorPoints) homeWon = true;
      if (visitorPoints > homePoints) visitorWon = true;
    }

    Widget buildTeamRow(dynamic t, bool isWon, int? points) {
      if (t == null) {
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              const SizedBox(width: 15),
              const Icon(Icons.grid_view, color: textMuted, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('POR DEFINIR', style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              Text('—', style: GoogleFonts.oswald(color: textMuted, fontSize: 16)),
              const SizedBox(width: 4),
            ],
          ),
        );
      }

      final seed = (t['position'] ?? t['seed'] ?? '').toString();
      final nameStr = (t['name'] ?? '').toString();
      final logoStr = widget.resolveMediaUrl((t['logo'] ?? '').toString());
      
      final words = nameStr.trim().split(RegExp(r'\s+'));
      String line1 = words.isNotEmpty ? words.first.toUpperCase() : '';
      String line2 = words.length > 1 ? words.sublist(1).join(' ').toUpperCase() : '';

      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 3, 4, 3),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              child: Text(
                seed,
                style: GoogleFonts.oswald(color: accentColor, fontSize: 13, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(3),
                image: logoStr.isNotEmpty ? DecorationImage(image: NetworkImage(logoStr), fit: BoxFit.cover) : null,
              ),
              child: logoStr.isEmpty ? const Icon(Icons.shield_outlined, color: Colors.grey, size: 20) : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    line1,
                    style: GoogleFonts.oswald(
                      color: isWon ? success : (isFinished ? textMuted : textPrimary),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (line2.isNotEmpty)
                    Text(
                      line2,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                points?.toString() ?? '—',
                style: GoogleFonts.oswald(
                  color: isWon ? accentColor : (isFinished && points != null ? textMuted : textPrimary),
                  fontSize: 16,
                  fontWeight: isWon ? FontWeight.w800 : FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 220,
      height: 100,
      decoration: BoxDecoration(
        color: brandBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Expanded(child: buildTeamRow(home, homeWon, homePoints)),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          Expanded(child: buildTeamRow(visitor, visitorWon, visitorPoints)),
        ],
      ),
    );
  }

  Widget _buildStandingsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_playoffsData != null) ...[
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.list_alt_outlined, color: textMuted, size: 16),
                const SizedBox(width: 8),
                Text(
                  'TABLA DE POSICIONES REGULAR',
                  style: GoogleFonts.oswald(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Header de columnas
        Container(
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 80),
              Expanded(child: Text('EQUIPO', style: GoogleFonts.inter(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold))),
              SizedBox(
                width: 185,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['JJ','JG','JP','PF','PC','DIF'].map((e) => 
                    SizedBox(width: 25, child: Text(e, style: GoogleFonts.inter(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center))
                  ).toList(),
                ),
              ),
              const SizedBox(width: 10), // Padding right
            ],
          ),
        ),
        
        // Filas
        ..._standingsData.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          if (item is! Map) return const SizedBox.shrink();
          
          final rank = idx + 1;
          final isEven = idx % 2 == 0;
          final teamId = (item['team_id'] ?? '').toString();
          final isMine = _isMyTeam(teamId);
          final isTop4 = rank <= 4 && !isMine;
          
          final teamNameRaw = (item['team_name'] ?? '').toString();
          final teamName = _getSmartTeamName(teamNameRaw);
          final logo = widget.resolveMediaUrl((item['logo'] ?? item['thumb'] ?? '').toString());
          
          final jj = (int.tryParse(item['pj']?.toString() ?? '') ?? 0) + (int.tryParse(item['pp']?.toString() ?? '') ?? 0);
          final pj = int.tryParse(item['pj']?.toString() ?? item['pg']?.toString() ?? '') ?? 0; // Use PJ logic from spec pg+pp or fallback
          final pg = int.tryParse(item['pg']?.toString() ?? '') ?? 0;
          final pp = int.tryParse(item['pp']?.toString() ?? '') ?? 0;
          final pf = int.tryParse(item['pf']?.toString() ?? '') ?? 0;
          final pc = int.tryParse(item['pc']?.toString() ?? '') ?? 0;
          final diffRaw = item['diff'] != null ? int.tryParse(item['diff'].toString()) : (pf - pc);
          final diff = diffRaw ?? 0;

          return InkWell(
            onTap: () => _showTeamStatsModal(Map<String,dynamic>.from(item)),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: isMine ? brandPrimary.withValues(alpha: 0.15) : (isEven ? Colors.transparent : Colors.white.withValues(alpha: 0.02)),
                border: Border(
                  bottom: const BorderSide(color: Colors.white12, width: 0.5),
                  left: isMine 
                    ? const BorderSide(color: brandPrimary, width: 4)
                    : isTop4
                      ? BorderSide(color: brandPrimary.withValues(alpha: 0.6), width: 3)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 25,
                    child: Text(
                      rank.toString(),
                      style: GoogleFonts.oswald(
                        color: isTop4 || isMine ? brandPrimary : textMuted.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: isTop4 || isMine ? FontWeight.w900 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Logo
                  Container(
                    width: 55,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: logo.isNotEmpty 
                      ? Transform.scale(
                          scale: 1.2,
                          child: CircleAvatar(backgroundImage: NetworkImage(logo), backgroundColor: Colors.transparent),
                        )
                      : const Icon(Icons.shield_outlined, color: Colors.grey, size: 20),
                  ),
                  // Name
                  Expanded(
                    child: Text(
                      teamName,
                      style: GoogleFonts.oswald(
                        color: rank == 1 || isMine ? brandPrimary : Colors.white,
                        fontSize: 13,
                        fontWeight: rank <= 4 || isMine ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Stats
                  SizedBox(
                    width: 185,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(width: 25, child: Text((pg+pp).toString(), style: GoogleFonts.oswald(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        SizedBox(width: 25, child: Text(pg.toString(), style: GoogleFonts.oswald(color: success, fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        SizedBox(width: 25, child: Text(pp.toString(), style: GoogleFonts.oswald(color: loss, fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        SizedBox(width: 25, child: Text(pf.toString(), style: GoogleFonts.oswald(color: textMuted, fontSize: 14), textAlign: TextAlign.center)),
                        SizedBox(width: 25, child: Text(pc.toString(), style: GoogleFonts.oswald(color: textMuted, fontSize: 14), textAlign: TextAlign.center)),
                        SizedBox(width: 25, child: Text(
                          diff > 0 ? '+$diff' : diff.toString(),
                          style: GoogleFonts.oswald(
                            color: diff > 0 ? brandPrimary : (diff < 0 ? danger : Colors.grey),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showTeamStatsModal(Map<String, dynamic> entry) {
    final statsData = _getTeamDetailStats(entry);
    final games = statsData['games'] as List<dynamic>;
    final stats = statsData['stats'] as Map<String, dynamic>;
    final streak = statsData['streak'] as Map;
    
    final teamName = entry['team_name']?.toString() ?? 'Equipo';
    final logo = widget.resolveMediaUrl((entry['logo'] ?? entry['thumb'] ?? '').toString());

    String streakLabel = '-';
    Color streakColor = Colors.grey;
    IconData streakIcon = Icons.remove;
    
    final sType = streak['type']?.toString() ?? '';
    final sLen = streak['length']?.toString() ?? '0';
    
    if (sType == 'G') { streakLabel = '$sLen Victorias'; streakColor = const Color(0xFF69F0AE); streakIcon = Icons.local_fire_department; }
    else if (sType == 'P') { streakLabel = '$sLen Derrotas'; streakColor = loss; streakIcon = Icons.ac_unit; }
    else if (sType == 'E') { streakLabel = '$sLen Empates'; streakColor = Colors.orange; streakIcon = Icons.drag_handle; }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Container(
            decoration: const BoxDecoration(
              color: brandSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white10,
                          image: logo.isNotEmpty ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover) : null,
                        ),
                        child: logo.isEmpty ? const Icon(Icons.shield, color: textMuted, size: 30) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teamName,
                              style: GoogleFonts.oswald(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: streakColor.withValues(alpha: 0.2),
                                border: Border.all(color: streakColor.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(streakIcon, color: streakColor, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    'RACHA: ${streakLabel.toUpperCase()}',
                                    style: GoogleFonts.inter(color: streakColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('RENDIMIENTO PROMEDIO', style: GoogleFonts.oswald(color: textMuted, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard('OFENSIVA', stats['avgFor'], 'PTS/J', Colors.greenAccent),
                          const SizedBox(width: 10),
                          _buildStatCard('DEFENSIVA', stats['avgAgainst'], 'REC/J', Colors.redAccent),
                          const SizedBox(width: 10),
                          _buildStatCard('SHUTOUTS', stats['shutouts'], 'JUEGOS', Colors.blueAccent),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CALENDARIO Y RESULTADOS', style: GoogleFonts.oswald(color: textMuted, fontSize: 14)),
                          Text('${games.length} Jugados', style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (games.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('Sin partidos registrados', style: TextStyle(color: textMuted))),
                        )
                      else
                        ...games.map((g) => _buildH2HRow(g)).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(title, style: GoogleFonts.inter(color: textMuted, fontSize: 8)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.oswald(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(unit, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildH2HRow(dynamic match) {
    if (match is! Map) return const SizedBox.shrink();
    
    final jor = match['journey']?.toString() ?? '1';
    final result = match['result']?.toString().toLowerCase() ?? '';
    
    String pf = '0';
    String pc = '0';
    if (match['score'] is Map) {
      pf = match['score']['pf']?.toString() ?? match['score']['home']?.toString() ?? '0';
      pc = match['score']['pc']?.toString() ?? match['score']['visitor']?.toString() ?? '0';
    } else {
      pf = match['points_for']?.toString() ?? '0';
      pc = match['points_against']?.toString() ?? '0';
    }

    final oppName = match['opponent_name']?.toString() ?? 'Rival';
    final oppLogo = widget.resolveMediaUrl((match['opponent_logo'] ?? '').toString());

    Color scoreColor = Colors.white;
    if (result == 'w') scoreColor = brandPrimary;
    if (result == 'l') scoreColor = danger;
    if (result == 'd') scoreColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text('JOR', style: GoogleFonts.inter(color: textMuted, fontSize: 8)),
              Text(jor, style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            width: 1, height: 30,
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '$pf - $pc',
              style: GoogleFonts.oswald(color: scoreColor, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    oppName,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white10,
                  backgroundImage: oppLogo.isNotEmpty ? NetworkImage(oppLogo) : null,
                  child: oppLogo.isEmpty ? const Icon(Icons.shield_outlined, color: textMuted, size: 16) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
