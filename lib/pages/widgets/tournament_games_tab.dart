import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../services/api_service.dart';
import '../../services/match_detail_route.dart';
import '../../services/storage_service.dart';
import '../../config/category_palette.dart';

// --- CLIPPERS SPORT SLASH ---
class LeftSlashClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.75, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class RightSlashClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.25, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TournamentGamesTab extends StatefulWidget {
  final ApiService api;
  final String tournamentId;
  final String modalidad;
  final String Function(String) resolveMediaUrl;

  const TournamentGamesTab({
    Key? key,
    required this.api,
    required this.tournamentId,
    required this.modalidad,
    required this.resolveMediaUrl,
  }) : super(key: key);

  @override
  State<TournamentGamesTab> createState() => _TournamentGamesTabState();
}

class _TournamentGamesTabState extends State<TournamentGamesTab> {
  // Stealth Colors
  static const Color brandBg = Color(0xFF0B101E);
  static const Color brandSurface = Color(0xFF131B2F);
  static const Color brandPrimary = Color(0xFF2DD4BF);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  bool _isLoadingMatches = true;
  List<dynamic> _allRawMatches = [];
  List<dynamic> _matchesDisplay = [];

  List<String> _availableJourneys = [];
  String _selectedJourneyKey = '';

  // Footer Filters
  bool _filterMisPartidos = false;
  bool _filterEnVivo = false;

  // Custom filters (Otros Filtros)
  String? _customFilterAcademy;
  Set<String> _customFilterCategories = {};

  // Session academy context
  String? _sessionAcademyId;
  String? _sessionAcademyName;

  // Selection keys
  String? _selectedDateKey; // yyyy-MM-dd
  String? _selectedHourKey; // HH:mm

  // Carousels controllers
  late PageController _datePageController;
  late PageController _hourPageController;

  int _revealGeneration = 0;

  @override
  void initState() {
    super.initState();
    _datePageController = PageController(viewportFraction: 0.26);
    _hourPageController = PageController(viewportFraction: 0.35);

    initializeDateFormatting('es_ES', null).then((_) {
      _loadAllMatches();
    });
  }

  @override
  void dispose() {
    _datePageController.dispose();
    _hourPageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMatches() async {
    setState(() {
      _isLoadingMatches = true;
    });

    try {
      // 1. Fetch matches
      final res = await widget.api.post('/getMatchesByTournament', {
        'token': widget.api.token,
        'tournamentId': widget.tournamentId,
      });

      // 2. Fetch session academy
      final userContext = await StorageService().getJson('user_context');
      if (userContext != null && userContext['academy'] != null) {
        _sessionAcademyId = (userContext['academy']['_id'] ?? '').toString();
        _sessionAcademyName = (userContext['academy']['name'] ?? '').toString();
      }

      if (!mounted) return;

      setState(() {
        _allRawMatches = res['matches'] as List<dynamic>? ?? [];
        _isLoadingMatches = false;
        _applyMatchFilters(isInitialLoad: true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMatches = false;
      });
    }
  }

  void _applyMatchFilters({bool isInitialLoad = false}) {
    if (_allRawMatches.isEmpty) {
      setState(() {
        _matchesDisplay = [];
        _availableJourneys = [];
      });
      return;
    }

    List<dynamic> pool = List.from(_allRawMatches);

    // 1. Apply custom filters (Otros Filtros)
    if (_customFilterAcademy != null) {
      pool = pool.where((m) {
        if (m is! Map) return false;
        final hAcad = _extractAcademy(m['home']);
        final vAcad = _extractAcademy(m['visitor']);
        final cat = _extractCategoryName(m);

        if (hAcad == _customFilterAcademy || vAcad == _customFilterAcademy) {
          if (_customFilterCategories.isEmpty || _customFilterCategories.contains(cat)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    // 2. Modalidad checks (Rafaga vs Regular)
    final mod = widget.modalidad.toLowerCase();
    final isRafaga = mod.contains('carrusel') || mod.contains('ráfaga') || mod.contains('rafaga');

    if (!isRafaga) {
      final Set<String> journeys = {};
      for (var m in pool) {
        if (m is Map) {
          final j = (m['journey'] ?? '').toString().trim();
          if (j.isNotEmpty) journeys.add(j);
        }
      }
      _availableJourneys = journeys.toList();
      _availableJourneys.sort(_compareJourneyKeys);

      if (isInitialLoad || _selectedJourneyKey.isEmpty || !_availableJourneys.contains(_selectedJourneyKey)) {
        _selectedJourneyKey = _autoSelectJourney(pool);
      }

      if (_selectedJourneyKey.isNotEmpty) {
        pool = pool.where((m) {
          if (m is! Map) return false;
          final j = (m['journey'] ?? '').toString().trim();
          return j.toLowerCase() == _selectedJourneyKey.toLowerCase();
        }).toList();
      }
    } else {
      _availableJourneys = [];
      _selectedJourneyKey = '';
    }

    // Sort pool by date ascending
    pool.sort((a, b) => _compareDates(a['date'], b['date']));

    // Extract unique dates
    final Set<String> datesSet = {};
    for (var m in pool) {
      final dk = _getDateKey(m);
      if (dk != 'Sin Fecha') datesSet.add(dk);
    }
    final List<String> availableDates = datesSet.toList()..sort();

    if (availableDates.isNotEmpty) {
      if (isInitialLoad || _selectedDateKey == null || !availableDates.contains(_selectedDateKey)) {
        _selectedDateKey = _autoSelectDate(availableDates);
      }
    } else {
      _selectedDateKey = null;
    }

    // Filter by selected date
    List<dynamic> datePool = pool;
    if (_selectedDateKey != null) {
      datePool = pool.where((m) => _getDateKey(m) == _selectedDateKey).toList();
    }

    // Extract unique hours
    final Set<String> hoursSet = {};
    for (var m in datePool) {
      final hk = _getHourKey(m);
      hoursSet.add(hk);
    }
    final List<String> availableHours = hoursSet.toList()..sort();

    if (availableHours.isNotEmpty) {
      if (isInitialLoad || _selectedHourKey == null || !availableHours.contains(_selectedHourKey)) {
        _selectedHourKey = _autoSelectHour(availableHours, _selectedDateKey);
      }
    } else {
      _selectedHourKey = null;
    }

    // Build display list for the current selected date & hour
    List<dynamic> displayList = datePool;
    if (_selectedHourKey != null) {
      displayList = datePool.where((m) => _getHourKey(m) == _selectedHourKey).toList();
    }

    // Apply Footer filters (Mis Partidos / En Vivo)
    if (_filterEnVivo) {
      displayList = displayList.where((m) {
        if (m is! Map) return false;
        final status = (m['gameStatus'] ?? m['status'] ?? '').toString();
        return status == 'live' || status == 'in_progress';
      }).toList();
    }

    if (_filterMisPartidos && _sessionAcademyId != null) {
      displayList = displayList.where((m) {
        if (m is! Map) return false;
        final hId = _extractAcademyId(m['home']);
        final vId = _extractAcademyId(m['visitor']);
        return hId == _sessionAcademyId || vId == _sessionAcademyId;
      }).toList();
    }

    setState(() {
      _matchesDisplay = displayList;
    });

    // Animate/jump pageview controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_datePageController.hasClients && _selectedDateKey != null) {
        final targetPage = availableDates.indexOf(_selectedDateKey!);
        if (targetPage != -1 && _datePageController.page?.round() != targetPage) {
          _datePageController.jumpToPage(targetPage);
        }
      }
      if (_hourPageController.hasClients && _selectedHourKey != null) {
        final targetPage = availableHours.indexOf(_selectedHourKey!);
        if (targetPage != -1 && _hourPageController.page?.round() != targetPage) {
          _hourPageController.jumpToPage(targetPage);
        }
      }
    });
  }

  // --- AUTO SELECTION HELPERS ---

  String _autoSelectJourney(List<dynamic> pool) {
    if (_availableJourneys.isEmpty) return '';
    final now = DateTime.now();
    dynamic closestMatch;
    Duration minDiff = const Duration(days: 9999);

    for (var m in pool) {
      if (m is! Map) continue;
      final dStr = (m['date'] ?? '').toString();
      if (dStr.isEmpty) continue;
      final d = DateTime.tryParse(dStr)?.toLocal();
      if (d == null) continue;

      final diff = d.difference(now).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestMatch = m;
      }
    }

    if (closestMatch != null) {
      final j = (closestMatch['journey'] ?? '').toString().trim();
      if (j.isNotEmpty && _availableJourneys.contains(j)) {
        return j;
      }
    }
    return _availableJourneys.first;
  }

  String _autoSelectDate(List<String> availableDates) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (availableDates.contains(todayStr)) return todayStr;

    final today = DateTime.now();
    String? closestDate;
    Duration minDiff = const Duration(days: 9999);

    for (var ds in availableDates) {
      try {
        final d = DateTime.parse(ds);
        final diff = d.difference(today).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestDate = ds;
        }
      } catch (_) {}
    }
    return closestDate ?? availableDates.first;
  }

  String _autoSelectHour(List<String> availableHours, String? dateStr) {
    if (dateStr == null || availableHours.isEmpty) return '';
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    if (dateStr == todayStr) {
      final nowMinutes = now.hour * 60 + now.minute;
      String? closestHour;
      int minDiff = 999999;

      for (var hs in availableHours) {
        final parts = hs.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final matchMinutes = h * 60 + m;

          final diff = (matchMinutes - nowMinutes).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestHour = hs;
          }
        }
      }
      return closestHour ?? availableHours.first;
    }
    return availableHours.first;
  }

  // --- DATA EXTRACTORS & HELPERS ---

  String _extractAcademy(dynamic team) {
    if (team == null || team is! Map) return '';
    final ac = team['academy'];
    if (ac != null) {
      if (ac is Map) return (ac['name'] ?? '').toString();
      final s = ac.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return (team['name'] ?? '').toString();
  }

  String _extractAcademyId(dynamic team) {
    if (team == null || team is! Map) return '';
    final ac = team['academy'];
    if (ac is Map) return (ac['id'] ?? ac['_id'] ?? '').toString();
    return (team['academyId'] ?? '').toString();
  }

  String _extractCategoryName(dynamic match) {
    if (match is! Map) return '';
    final c = match['category'];
    if (c is Map) return (c['name'] ?? '').toString();
    return c?.toString() ?? '';
  }

  String _getDateKey(dynamic match) {
    if (match is! Map) return 'Sin Fecha';
    final dStr = (match['date'] ?? '').toString();
    if (dStr.isEmpty) return 'Sin Fecha';
    try {
      final d = DateTime.parse(dStr).toLocal();
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      final parts = dStr.split('T');
      return parts.isNotEmpty ? parts[0] : 'Sin Fecha';
    }
  }

  String _getHourKey(dynamic match) {
    if (match is! Map) return '00:00';
    final dStr = (match['date'] ?? '').toString();
    if (dStr.isEmpty) return '00:00';
    try {
      final d = DateTime.parse(dStr).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      final parts = dStr.split('T');
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        if (timeParts.length >= 2) {
          return '${timeParts[0]}:${timeParts[1]}';
        }
      }
      return '00:00';
    }
  }

  String _extractSede(dynamic match) {
    if (match is! Map) return 'Sede';
    final s = match['sede'] ?? match['location'];
    if (s is Map) return (s['name'] ?? s['alias'] ?? 'Sede').toString();
    final str = s?.toString().trim();
    if (str != null && str.isNotEmpty) return str;

    final f = match['field'];
    if (f != null && f.toString().trim().isNotEmpty) return 'Campo $f';
    return 'Sede';
  }

  int _compareDates(dynamic dA, dynamic dB) {
    final a = dA?.toString() ?? '';
    final b = dB?.toString() ?? '';
    return a.compareTo(b);
  }

  int _compareJourneyKeys(String a, String b) {
    final numA = int.tryParse(a);
    final numB = int.tryParse(b);
    if (numA != null && numB != null) return numA.compareTo(numB);
    if (numA != null && numB == null) return -1;
    if (numB != null && numA == null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  String _formatDateTab(String raw) {
    if (raw == 'Sin Fecha') return 'SIN FECHA';
    try {
      final d = DateTime.parse(raw);
      return DateFormat('EEE, d MMM', 'es_ES').format(d);
    } catch (_) {
      return raw;
    }
  }

  String _formatHourKey(String hs) {
    try {
      final parts = hs.split(':');
      final now = DateTime.now();
      final d = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a', 'es_ES').format(d);
    } catch (_) {
      return hs;
    }
  }

  String _smartName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    final words = clean.split(RegExp(r'\s+'));
    if (words.length > 2) return words.first.toUpperCase();
    return clean.toUpperCase();
  }

  // --- RENDERING METHOD ---

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandBg,
      child: Stack(
        children: [
          Column(
            children: [
              _buildStickyHeader(),
              Expanded(
                child: _isLoadingMatches
                    ? _buildSkeletonList()
                    : _buildMatchesList(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildFooterFilters(),
          ),
        ],
      ),
    );
  }

  // --- STICKY HEADER ---

  Widget _buildStickyHeader() {
    final mod = widget.modalidad.toLowerCase();
    final isRafaga = mod.contains('carrusel') || mod.contains('ráfaga') || mod.contains('rafaga');
    
    // Extract dates and hours for the selector
    List<dynamic> journeyMatches = _allRawMatches;
    if (!isRafaga && _selectedJourneyKey.isNotEmpty) {
      journeyMatches = _allRawMatches.where((m) {
        final j = (m['journey'] ?? '').toString().trim();
        return j.toLowerCase() == _selectedJourneyKey.toLowerCase();
      }).toList();
    }
    
    final Set<String> datesSet = {};
    for (var m in journeyMatches) {
      final dk = _getDateKey(m);
      if (dk != 'Sin Fecha') datesSet.add(dk);
    }
    final List<String> availableDates = datesSet.toList()..sort();

    List<dynamic> dateMatches = journeyMatches;
    if (_selectedDateKey != null) {
      dateMatches = journeyMatches.where((m) => _getDateKey(m) == _selectedDateKey).toList();
    }

    final Set<String> hoursSet = {};
    for (var m in dateMatches) {
      hoursSet.add(_getHourKey(m));
    }
    final List<String> availableHours = hoursSet.toList()..sort();

    final showHours = availableHours.length > 1;
    final double headerHeight = showHours ? 89.0 : 55.0;

    return Container(
      height: headerHeight,
      decoration: const BoxDecoration(
        color: brandSurface,
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Column(
        children: [
          // Dates and Journey Row
          SizedBox(
            height: 48,
            child: Row(
              children: [
                if (!isRafaga && _availableJourneys.isNotEmpty) ...[
                  GestureDetector(
                    onTap: _showJourneySelectionModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JORNADA',
                                style: GoogleFonts.inter(
                                  color: textMuted,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _selectedJourneyKey,
                                    style: GoogleFonts.oswald(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 14),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(width: 1, height: 28, color: Colors.white24),
                        ],
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: availableDates.isEmpty
                      ? Center(child: Text('Sin fechas', style: GoogleFonts.inter(color: textMuted, fontSize: 12)))
                      : PageView.builder(
                          controller: _datePageController,
                          itemCount: availableDates.length,
                          onPageChanged: (idx) {
                            if (_selectedDateKey != availableDates[idx]) {
                              setState(() {
                                _selectedDateKey = availableDates[idx];
                                _selectedHourKey = null;
                                _revealGeneration++;
                              });
                              _applyMatchFilters();
                            }
                          },
                          itemBuilder: (ctx, idx) {
                            final ds = availableDates[idx];
                            final isSelected = ds == _selectedDateKey;
                            return GestureDetector(
                              onTap: () {
                                _datePageController.animateToPage(
                                  idx,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Text(
                                  _formatDateTab(ds),
                                  style: GoogleFonts.inter(
                                    color: isSelected ? brandPrimary : textMuted,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
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
          if (showHours) ...[
            Container(height: 0.5, color: Colors.white12),
            SizedBox(
              height: 40,
              child: PageView.builder(
                controller: _hourPageController,
                itemCount: availableHours.length,
                onPageChanged: (idx) {
                  if (_selectedHourKey != availableHours[idx]) {
                    setState(() {
                      _selectedHourKey = availableHours[idx];
                      _revealGeneration++;
                    });
                    _applyMatchFilters();
                  }
                },
                itemBuilder: (ctx, idx) {
                  final hs = availableHours[idx];
                  final isSelected = hs == _selectedHourKey;
                  return GestureDetector(
                    onTap: () {
                      _hourPageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.access_time_filled, color: brandPrimary, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _formatHourKey(hs),
                            style: GoogleFonts.inter(
                              color: isSelected ? brandPrimary : textMuted,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- MATCHES LIST & SKELETONS ---

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: 3,
      itemBuilder: (ctx, idx) {
        return Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: brandSurface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: brandPrimary),
          ),
        );
      },
    );
  }

  Widget _buildMatchesList() {
    if (_matchesDisplay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No hay partidos con estos filtros',
            style: GoogleFonts.inter(color: textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Group matches by Venue (Sede)
    final Map<String, List<dynamic>> venueGroups = {};
    for (var m in _matchesDisplay) {
      final s = _extractSede(m);
      venueGroups.putIfAbsent(s, () => []).add(m);
    }

    // Sort venues alphabetically
    final sortedVenues = venueGroups.keys.toList()..sort();

    return ListView.builder(
      key: ValueKey('reveal_$_revealGeneration'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sortedVenues.length,
      itemBuilder: (ctx, vIdx) {
        final venueName = sortedVenues[vIdx];
        final matches = venueGroups[venueName]!;

        // Sort matches by field (numeric or alphabetic) within venue
        matches.sort((a, b) {
          final fA = a['field']?.toString() ?? '';
          final fB = b['field']?.toString() ?? '';
          final nA = int.tryParse(fA);
          final nB = int.tryParse(fB);
          if (nA != null && nB != null) return nA.compareTo(nB);
          return fA.compareTo(fB);
        });

        // Search for a match that brings forecast/weather info
        Map<String, dynamic>? weatherSample;
        for (var m in matches) {
          if (m is Map && m['weather'] != null) {
            weatherSample = Map<String, dynamic>.from(m);
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Venue Sticky-like Header
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.place, color: brandPrimary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      venueName.toUpperCase(),
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (weatherSample != null)
                    _buildWeatherChip(weatherSample),
                ],
              ),
            ),
            // Venue Matches List
            ...matches.map((m) => ProMatchCard(
              matchData: Map<String, dynamic>.from(m),
              revealGeneration: _revealGeneration,
              revealIndex: matches.indexOf(m),
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildWeatherChip(Map<String, dynamic> match) {
    final w = match['weather'];
    final temp = (w['temp'] ?? '').toString();
    final icon = (w['icon'] ?? 'sunny').toString();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon.contains('rain') ? Icons.umbrella : Icons.wb_sunny,
            color: Colors.amber,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$temp°C',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- FOOTER FILTERS ---

  Widget _buildFooterFilters() {
    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mis Partidos Toggle
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _filterMisPartidos = !_filterMisPartidos;
                  _revealGeneration++;
                });
                _applyMatchFilters();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield,
                    color: _filterMisPartidos ? brandPrimary : textMuted,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MIS PARTIDOS',
                    style: GoogleFonts.inter(
                      color: _filterMisPartidos ? Colors.white : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // En Vivo Toggle
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _filterEnVivo = !_filterEnVivo;
                  _revealGeneration++;
                });
                _applyMatchFilters();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sensors,
                    color: _filterEnVivo ? brandPrimary : textMuted,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'EN VIVO',
                    style: GoogleFonts.inter(
                      color: _filterEnVivo ? Colors.white : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Otros Filtros button
          Expanded(
            child: InkWell(
              onTap: _showAdvancedFiltersModal,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tune,
                    color: (_customFilterAcademy != null || _customFilterCategories.isNotEmpty)
                        ? brandPrimary
                        : textMuted,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OTROS FILTROS',
                    style: GoogleFonts.inter(
                      color: (_customFilterAcademy != null || _customFilterCategories.isNotEmpty)
                          ? Colors.white
                          : textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODALS (JOURNEY & FILTERS) ---

  void _showJourneySelectionModal() {
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
                color: Color(0xFF131B2F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text(
                    'SELECCIONAR JORNADA',
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
                      itemCount: _availableJourneys.length,
                      itemBuilder: (ctx, idx) {
                        final j = _availableJourneys[idx];
                        final isSel = j == _selectedJourneyKey;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedJourneyKey = j;
                              _selectedDateKey = null;
                              _selectedHourKey = null;
                              _revealGeneration++;
                            });
                            _applyMatchFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            color: isSel ? brandPrimary.withOpacity(0.1) : Colors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'JORNADA $j'.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: isSel ? Colors.white : Colors.white70,
                                      fontSize: 14,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSel) const Icon(Icons.check, color: brandPrimary, size: 20),
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

  void _showAdvancedFiltersModal() {
    // Extract unique academies and categories present in allRawMatches
    final Set<String> academies = {};
    final Set<String> categories = {};
    for (var m in _allRawMatches) {
      final h = _extractAcademy(m['home']);
      final v = _extractAcademy(m['visitor']);
      if (h.isNotEmpty) academies.add(h);
      if (v.isNotEmpty) academies.add(v);

      final cat = _extractCategoryName(m);
      if (cat.isNotEmpty) categories.add(cat);
    }
    
    final sortedAcademies = academies.toList()..sort();
    final sortedCategories = categories.toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF131B2F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text(
                    'FILTROS DE PARTIDOS',
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Academy selection dropdown or list
                        Text(
                          'ACADEMIA',
                          style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _customFilterAcademy,
                            hint: Text('Selecciona academia', style: GoogleFonts.inter(color: textMuted, fontSize: 13)),
                            isExpanded: true,
                            dropdownColor: const Color(0xFF131B2F),
                            underline: const SizedBox.shrink(),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text('TODAS LAS ACADEMIAS', style: GoogleFonts.inter(color: brandPrimary)),
                              ),
                              ...sortedAcademies.map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a),
                                  )),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                _customFilterAcademy = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Categories multiselect
                        Text(
                          'CATEGORÍAS',
                          style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: sortedCategories.map((c) {
                            final isSel = _customFilterCategories.contains(c);
                            final catPal = CategoryPalette.getColors(c);
                            final bg = catPal['bg'] as Color;

                            return ChoiceChip(
                              label: Text(c.toUpperCase()),
                              selected: isSel,
                              selectedColor: bg.withOpacity(0.25),
                              backgroundColor: Colors.black26,
                              labelStyle: GoogleFonts.oswald(
                                color: isSel ? bg : textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSel ? bg : Colors.white10,
                                ),
                              ),
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    _customFilterCategories.add(c);
                                  } else {
                                    _customFilterCategories.remove(c);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 40),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _customFilterAcademy = null;
                                    _customFilterCategories.clear();
                                  });
                                },
                                child: Text(
                                  'LIMPIAR FILTROS',
                                  style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandPrimary,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _revealGeneration++;
                                  });
                                  _applyMatchFilters();
                                },
                                child: Text(
                                  'APLICAR',
                                  style: GoogleFonts.oswald(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
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
}

// --- PRO MATCH CARD ---

class ProMatchCard extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final bool isFinished;
  final int? revealGeneration;
  final int? revealIndex;

  static const Color _cardBackground = Color(0xFF141C2E);
  static const Color _metaColumnBackground = Color(0xFF080B12);
  static const EdgeInsets _cardMargin = EdgeInsets.fromLTRB(0, 0, 4, 14);
  static const double _cardHeight = 92;
  static const double _cardRadius = 16;
  static const double _metaColumnWidth = 32;
  static const double _metaColumnHeight = 80;
  static const double _categoryStripWidth = 8;
  static const double _contentPanelLeftRadius = 14;
  static const double _logoOuterSize = 58;
  static const double _logoInnerSize = 52;

  const ProMatchCard({
    Key? key,
    required this.matchData,
    this.isFinished = false,
    this.revealGeneration,
    this.revealIndex,
  }) : super(key: key);

  static String extractAcademy(dynamic team) {
    if (team == null || team is! Map) return '';
    final ac = team['academy'];
    if (ac != null) {
      if (ac is Map) return (ac['name'] ?? '').toString();
      final s = ac.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return (team['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final String status = matchData['gameStatus'] ?? 'scheduled';
    final bool isLive = status == 'live' || status == 'in_progress';
    final bool finalIsFinished = isFinished || status == 'finished';

    return _wrapWithTap(
      context,
      _buildMatchCard(isLive: isLive, isFinished: finalIsFinished),
      borderRadius: _cardRadius,
    );
  }

  Widget _wrapWithTap(
    BuildContext context,
    Widget child, {
    required double borderRadius,
  }) {
    final String matchId =
        (matchData['_id'] ?? matchData['id'])?.toString() ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: matchId.isEmpty
            ? null
            : () {
                Navigator.pushNamed(
                  context,
                  MatchDetailRoute.routeFor(matchId),
                  arguments: MatchDetailRouteArgs(
                    matchId: matchId,
                    matchSnapshot: matchData,
                  ),
                );
              },
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: child,
      ),
    );
  }

  String _categoryShortName(String categoryName) {
    return categoryName.trim().split(' ').first.toUpperCase();
  }

  Widget _buildCategoryHeader(String categoryName, Color labelColor) {
    return Text(
      _categoryShortName(categoryName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.oswald(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: labelColor,
        height: 1,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCategoryHorizontalStrip(Map<String, Color> catUi) {
    final fill = catUi['horizontalFill']!;
    final glow = catUi['horizontalGlow']!;

    return Container(
      width: _metaColumnWidth * 0.38,
      height: 2,
      decoration: BoxDecoration(
        color: fill.withOpacity(0.8),
        borderRadius: BorderRadius.circular(1),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.2),
            blurRadius: 7,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLabelBlock({
    required String categoryName,
    required Map<String, Color> catUi,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCategoryHeader(categoryName, catUi['label']!),
        const SizedBox(height: 3),
        _buildCategoryHorizontalStrip(catUi),
      ],
    );
  }

  Widget _buildCategoryVerticalStrip(Map<String, Color> catUi) {
    final fill = catUi['verticalFill']!;
    final support = catUi['horizontalFill']!;
    final glow = catUi['verticalGlow']!;

    return Container(
      width: _categoryStripWidth,
      height: _metaColumnHeight * 0.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_categoryStripWidth / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fill,
            Color.lerp(fill, support, 0.45) ?? support,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(2, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaColumn({required String? fieldLabel}) {
    return Container(
      width: _metaColumnWidth,
      height: _metaColumnHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _metaColumnBackground.withOpacity(0),
            _metaColumnBackground.withOpacity(0.45),
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.03), width: 1),
          bottom: BorderSide(color: Colors.white.withOpacity(0.03), width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        fieldLabel ?? '—',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.oswald(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFF8FAFC).withOpacity(0.9),
          height: 1.05,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String? _fieldColumnLabel() {
    final raw = matchData['field']?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final upper = raw.toUpperCase();
    if (upper.startsWith('C')) return upper;
    return 'C$raw';
  }

  static final DateFormat _scheduledDayFormat = DateFormat('EEE d MMM', 'es_ES');
  static final DateFormat _scheduledTimeFormat = DateFormat('h:mm a', 'es_ES');

  DateTime? _matchDateTime() {
    final raw = matchData['date']?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TextStyle _scheduledMetaStyle() {
    return GoogleFonts.oswald(
      fontSize: 7,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF94A3B8).withOpacity(0.8),
      letterSpacing: 0.8,
      height: 1,
    );
  }

  Widget _buildScheduledMetaBlock() {
    final matchDate = _matchDateTime();
    final style = _scheduledMetaStyle();

    if (matchDate == null) {
      return Text('PROGRAMADO', style: style);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _scheduledDayFormat.format(matchDate).toUpperCase(),
          style: style,
        ),
        const SizedBox(height: 2),
        Text(
          _scheduledTimeFormat.format(matchDate).toUpperCase(),
          style: style,
        ),
      ],
    );
  }

  Widget _buildVsCenter({
    required String categoryName,
    required Map<String, Color> catUi,
  }) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCategoryLabelBlock(
              categoryName: categoryName,
              catUi: catUi,
            ),
            const SizedBox(height: 5),
            _buildScheduledMetaBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCenter({
    required String categoryName,
    required Map<String, Color> catUi,
    required int pf,
    required int pc,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCategoryLabelBlock(
            categoryName: categoryName,
            catUi: catUi,
          ),
          const SizedBox(height: 4),
          const LiveIndicator(),
          const SizedBox(height: 6),
          _buildScoreRow(pf: pf, pc: pc, isLive: true),
        ],
      ),
    );
  }

  Widget _buildFinishedCenter({
    required String categoryName,
    required Map<String, Color> catUi,
    required int pf,
    required int pc,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCategoryLabelBlock(
            categoryName: categoryName,
            catUi: catUi,
          ),
          const SizedBox(height: 4),
          Text(
            'FINALIZADO',
            style: GoogleFonts.oswald(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8).withOpacity(0.8),
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          _buildScoreRow(pf: pf, pc: pc, isLive: false),
        ],
      ),
    );
  }

  Widget _buildScoreRow({
    required int pf,
    required int pc,
    required bool isLive,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$pf', style: _scoreStyle(isLive)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              '-',
              style: _scoreStyle(isLive).copyWith(
                fontSize: isLive ? 18 : 14,
                color: Colors.white24,
              ),
            ),
          ),
          Text('$pc', style: _scoreStyle(isLive)),
        ],
      ),
    );
  }

  Widget _buildCenterContent({
    required bool isLive,
    required bool isFinished,
    required int pf,
    required int pc,
    required String category,
    required Map<String, Color> catUi,
  }) {
    if (isLive) {
      return _buildLiveCenter(
        categoryName: category,
        catUi: catUi,
        pf: pf,
        pc: pc,
      );
    }
    if (isFinished) {
      return _buildFinishedCenter(
        categoryName: category,
        catUi: catUi,
        pf: pf,
        pc: pc,
      );
    }
    return _buildVsCenter(categoryName: category, catUi: catUi);
  }

  Widget _buildTeamAvatarColumn(
    String url,
    dynamic team, {
    required int teamSide,
  }) {
    const double outer = _logoOuterSize;
    const double inner = _logoInnerSize;
    final parts = _parseTeamDisplay(team);

    final logo = Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x55FFFFFF),
            Color(0x11FFFFFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.27),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        width: inner,
        height: inner,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF12182A),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                width: inner,
                height: inner,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white.withOpacity(0.03),
                  child: Icon(
                    Icons.shield,
                    color: Colors.white24,
                    size: inner * 0.38,
                  ),
                ),
              )
            : Container(
                color: Colors.white.withOpacity(0.03),
                child: Icon(
                  Icons.shield,
                  color: Colors.white24,
                  size: inner * 0.38,
                ),
              ),
      ),
    );

    final name = SizedBox(
      width: outer + 10,
      child: _buildTeamNameLabel(parts),
    );

    Widget column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(height: 4),
        name,
      ],
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: column,
    );
  }

  Widget _buildTeamNameLabel(_TeamDisplayParts parts) {
    final baseStyle = GoogleFonts.inter(
      fontSize: 7,
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.88),
      letterSpacing: 0.1,
      height: 1,
    );

    final suffixStyle = GoogleFonts.inter(
      fontSize: 7,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2DD4BF).withOpacity(0.95),
      letterSpacing: 0.15,
      height: 1,
    );

    const textHeight = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );

    if (parts.suffix == null) {
      return Text(
        parts.base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        textHeightBehavior: textHeight,
        style: baseStyle,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            parts.base,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            textHeightBehavior: textHeight,
            strutStyle: const StrutStyle(
              fontSize: 7,
              height: 1,
              forceStrutHeight: true,
            ),
            style: baseStyle,
          ),
        ),
        Text(
          ' · ${parts.suffix}',
          textHeightBehavior: textHeight,
          strutStyle: const StrutStyle(
            fontSize: 7,
            height: 1,
            forceStrutHeight: true,
          ),
          style: suffixStyle,
        ),
      ],
    );
  }

  static const Set<String> _teamSuffixTokens = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
    'orange', 'blue', 'white', 'dark', 'gold', 'red', 'black', 'green',
    'yellow', 'silver', 'plata', 'bronce', 'bronze', 'norte', 'sur',
    'este', 'oeste', 'north', 'south', 'east', 'west',
    'varsity', 'jv', 'rookie', 'elite', 'select',
  };

  static const Set<String> _academyPrefixWords = {
    'academia', 'club', 'escuela', 'instituto', 'team', 'equipo', 'cd',
  };

  _TeamDisplayParts _parseTeamDisplay(dynamic team) {
    final teamName = (team is Map ? team['name'] : null)?.toString().trim() ?? '';
    final academyName = extractAcademy(team).trim();

    if (teamName.isEmpty && academyName.isEmpty) {
      return const _TeamDisplayParts(base: 'EQUIPO', suffix: null);
    }

    final paren = RegExp(r'\(([^)]+)\)').firstMatch(teamName);
    if (paren != null) {
      final suffix = _normalizeSuffix(paren.group(1) ?? '');
      final baseSource = teamName.replaceAll(paren.group(0)!, '').trim();
      final base = _abbreviateAcademy(
        baseSource.isNotEmpty ? baseSource : academyName,
      );
      if (suffix != null) {
        return _TeamDisplayParts(base: base, suffix: suffix);
      }
    }

    final dashParts = teamName.split(RegExp(r'\s*[-–|/]\s*'));
    if (dashParts.length >= 2) {
      final suffixCandidate = dashParts.last.trim();
      final baseSource = dashParts.sublist(0, dashParts.length - 1).join(' - ').trim();
      final suffix = _compactSuffix(suffixCandidate);
      if (suffix != null && baseSource.isNotEmpty) {
        return _TeamDisplayParts(
          base: _abbreviateAcademy(baseSource.isNotEmpty ? baseSource : academyName),
          suffix: suffix,
        );
      }
    }

    if (academyName.isNotEmpty && teamName.isNotEmpty) {
      final remainder = _stripAcademyPrefix(teamName, academyName);
      if (remainder != null && remainder.isNotEmpty) {
        final suffix = _compactSuffix(remainder);
        if (suffix != null) {
          return _TeamDisplayParts(
            base: _abbreviateAcademy(academyName),
            suffix: suffix,
          );
        }
      }

      final teamWords = teamName.split(RegExp(r'\s+'));
      final academyWords = academyName.split(RegExp(r'\s+'));
      if (teamWords.length > academyWords.length) {
        final extra = teamWords.sublist(academyWords.length).join(' ');
        final suffix = _compactSuffix(extra);
        if (suffix != null) {
          return _TeamDisplayParts(
            base: _abbreviateAcademy(academyName),
            suffix: suffix,
          );
        }
      }
    }

    final words = teamName.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final lastWord = words.last;
      if (_isKnownSuffixToken(lastWord)) {
        return _TeamDisplayParts(
          base: _abbreviateAcademy(words.sublist(0, words.length - 1).join(' ')),
          suffix: _normalizeSuffix(lastWord),
        );
      }
    }

    final source = teamName.isNotEmpty ? teamName : academyName;
    return _TeamDisplayParts(base: _abbreviateAcademy(source), suffix: null);
  }

  String? _stripAcademyPrefix(String teamName, String academyName) {
    final lowerTeam = teamName.toLowerCase();
    final lowerAca = academyName.toLowerCase();
    if (!lowerTeam.startsWith(lowerAca)) return null;

    var remainder = teamName.substring(academyName.length).trim();
    remainder = remainder.replaceFirst(RegExp(r'^[-–|/]\s*'), '').trim();
    remainder = remainder.replaceFirst(
      RegExp(r'^(equipo|team)\s+', caseSensitive: false),
      '',
    ).trim();
    return remainder.isEmpty ? null : remainder;
  }

  String? _compactSuffix(String value) {
    final clean = value.trim();
    if (clean.isEmpty || clean.length > 24) return null;

    final words = clean.split(RegExp(r'\s+'));
    if (words.length == 1) return _normalizeSuffix(words.first);

    if (clean.length <= 18) return _normalizeSuffix(clean);

    return _normalizeSuffix(words.last);
  }

  bool _isKnownSuffixToken(String value) {
    final token = value.trim().toLowerCase();
    if (token.isEmpty) return false;
    if (token.length == 1 && RegExp(r'^[a-z]$').hasMatch(token)) return true;
    return _teamSuffixTokens.contains(token);
  }

  String? _normalizeSuffix(String value) {
    final token = value.trim();
    if (token.isEmpty) return null;
    if (token.length == 1) return token.toUpperCase();
    return token.toUpperCase();
  }

  String _abbreviateAcademy(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    if (words.length <= 2) return name.trim().toUpperCase();

    final first = words.first.toLowerCase();
    if (_academyPrefixWords.contains(first) && words.length >= 2) {
      return '${words[0]} ${words[1]}'.toUpperCase();
    }

    return words.first.toUpperCase();
  }

  Widget _buildMatchCardContent({
    required String? fieldLabel,
    required Map<String, Color> catUi,
    required String homeLogo,
    required dynamic home,
    required String visitorLogo,
    required dynamic visitor,
    required Widget center,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: _buildMetaColumn(fieldLabel: fieldLabel),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_contentPanelLeftRadius),
                    bottomLeft: Radius.circular(_contentPanelLeftRadius),
                    topRight: Radius.circular(_cardRadius),
                    bottomRight: Radius.circular(_cardRadius),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
                      offset: const Offset(-1, 0),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildTeamAvatarColumn(
                            homeLogo,
                            home,
                            teamSide: 0,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.center,
                          child: center,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildTeamAvatarColumn(
                            visitorLogo,
                            visitor,
                            teamSide: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: _metaColumnWidth - _categoryStripWidth / 2,
          top: 0,
          bottom: 0,
          child: Center(
            child: _buildCategoryVerticalStrip(catUi),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard({
    required bool isLive,
    required bool isFinished,
  }) {
    final home = matchData['home'] ?? {};
    final visitor = matchData['visitor'] ?? {};
    final int pf = int.tryParse(home['points']?.toString() ?? '0') ?? 0;
    final int pc = int.tryParse(visitor['points']?.toString() ?? '0') ?? 0;
    final String homeLogo = home['logo'] ?? '';
    final String visitorLogo = visitor['logo'] ?? '';
    final String category =
        (matchData['category'] is Map
            ? matchData['category']['name']
            : matchData['category']?.toString()) ??
        'Gen';

    final catUi = CategoryPalette.uiForDarkCard(category);
    final fieldLabel = _fieldColumnLabel();

    return Container(
      height: _cardHeight,
      margin: _cardMargin,
      color: Colors.transparent,
      clipBehavior: Clip.none,
      child: _buildMatchCardContent(
        fieldLabel: fieldLabel,
        catUi: catUi,
        homeLogo: homeLogo,
        home: home,
        visitorLogo: visitorLogo,
        visitor: visitor,
        center: _buildCenterContent(
          isLive: isLive,
          isFinished: isFinished,
          pf: pf,
          pc: pc,
          category: category,
          catUi: catUi,
        ),
      ),
    );
  }

  TextStyle _scoreStyle(bool isLive) {
    return GoogleFonts.oswald(
      fontSize: isLive ? 26 : 20,
      fontWeight: FontWeight.bold,
      color: isLive ? Colors.white : Colors.white70,
      height: 1,
    );
  }
}

class _TeamDisplayParts {
  final String base;
  final String? suffix;

  const _TeamDisplayParts({required this.base, required this.suffix});
}

class LiveIndicator extends StatefulWidget {
  const LiveIndicator({Key? key}) : super(key: key);

  @override
  State<LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final neonRed = const Color(0xFFFF003C);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: neonRed.withOpacity(0.1 + 0.1 * _controller.value),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: neonRed.withOpacity(0.4 + 0.6 * _controller.value),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: neonRed.withOpacity(0.3 * _controller.value),
                blurRadius: 10 * _controller.value,
                spreadRadius: 1 * _controller.value,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: neonRed.withOpacity(0.5 + 0.5 * _controller.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: neonRed,
                      blurRadius: 4 * _controller.value,
                      spreadRadius: 1 * _controller.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "EN VIVO",
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: neonRed,
                      blurRadius: 8 * _controller.value,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
