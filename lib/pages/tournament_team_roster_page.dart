import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../utils/match_helpers.dart';

class TournamentTeamRosterPage extends StatefulWidget {
  const TournamentTeamRosterPage({
    super.key,
    required this.api,
    required this.teamId,
    required this.resolveMediaUrl,
    this.previewName = 'Equipo',
    this.categoryLabel = '',
    this.groupLabel,
  });

  final ApiService api;
  final String teamId;
  final String Function(String) resolveMediaUrl;
  final String previewName;
  final String categoryLabel;
  final String? groupLabel;

  @override
  State<TournamentTeamRosterPage> createState() => _TournamentTeamRosterPageState();
}

class _TournamentTeamRosterPageState extends State<TournamentTeamRosterPage> {
  bool _loading = true;
  String _error = '';

  Map<String, dynamic>? _team;
  List<Map<String, dynamic>> _roster = [];
  Map<String, dynamic>? _attendanceSummary;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await widget.api.getTeamRosterAttendance(widget.teamId);
      if (!mounted) return;

      if (res['status'] != 'ok') {
        setState(() {
          _loading = false;
          _error = (res['message'] ?? 'No se pudo cargar el roster').toString();
        });
        return;
      }

      final team = res['team'];
      final roster = (res['roster'] as List<dynamic>?) ?? [];

      setState(() {
        _team = team is Map ? Map<String, dynamic>.from(team) : null;
        _roster = roster.whereType<Map>().map((p) => Map<String, dynamic>.from(p)).toList();
        _attendanceSummary = res['attendanceSummary'] is Map
            ? Map<String, dynamic>.from(res['attendanceSummary'] as Map)
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error de conexión: $e';
      });
    }
  }

  String get _teamName =>
      (_team?['name'] ?? widget.previewName).toString();

  bool _playerIsPresent(Map<String, dynamic> player) {
    final attendance = player['attendance'];
    if (attendance is Map) {
      return attendance['isPresent'] == true;
    }
    return player['isPresent'] == true || player['snapshotAttended'] == true;
  }

  int? _attendanceValue(Map<String, dynamic> player) {
    final attendance = player['attendance'];
    if (attendance is Map && attendance['value'] != null) {
      return (attendance['value'] as num).toInt();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.navyPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _loading ? widget.previewName : _teamName,
          style: GoogleFonts.oswald(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.brandTeal));
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadRoster, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final logoUrl = widget.resolveMediaUrl(
      (_team?['logo'] ?? _team?['thumb'] ?? '').toString(),
    );
    final academy = _team?['academy'];
    final academyName = academy is Map ? (academy['name'] ?? '').toString() : '';
    final category = _team?['category'];
    final categoryShort = category is Map
        ? (category['shortName'] ?? category['name'] ?? '').toString()
        : widget.categoryLabel;
    final gpo = (_team?['gpo'] ?? widget.groupLabel)?.toString();
    final points = _team?['points'];

    return RefreshIndicator(
      color: AppTheme.brandTeal,
      backgroundColor: AppTheme.navyPrimary,
      onRefresh: _loadRoster,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildHeader(
            logoUrl: logoUrl,
            academyName: academyName,
            categoryShort: categoryShort,
            groupLabel: gpo,
            points: points,
          ),
          if (_attendanceSummary != null) ...[
            const SizedBox(height: 12),
            _buildAttendanceSummary(),
          ],
          const SizedBox(height: 20),
          Text(
            'ROSTER (${_roster.length})',
            style: GoogleFonts.oswald(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.brandTeal,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (_roster.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Este equipo no tiene jugadores en el roster.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ..._roster.map(_playerTile),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final total = (_attendanceSummary!['totalPlayers'] as num?)?.toInt() ?? _roster.length;
    final present = (_attendanceSummary!['presentCount'] as num?)?.toInt() ?? 0;
    final absent = (_attendanceSummary!['absentCount'] as num?)?.toInt() ?? 0;
    final pct = (_attendanceSummary!['attendancePercentage'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryStat('Total', '$total', Colors.white70)),
          Expanded(child: _summaryStat('Presentes', '$present', AppTheme.success)),
          Expanded(child: _summaryStat('Ausentes', '$absent', AppTheme.error)),
          Expanded(child: _summaryStat('Asist.', '${pct.toStringAsFixed(0)}%', AppTheme.brandTeal)),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.oswald(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      ],
    );
  }

  Widget _buildHeader({
    required String logoUrl,
    required String academyName,
    required String categoryShort,
    required String? groupLabel,
    required dynamic points,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.navyPrimary,
              border: Border.all(color: AppTheme.brandTeal, width: 2),
            ),
            child: ClipOval(
              child: logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.shield, color: Colors.white38, size: 36),
                    )
                  : const Icon(Icons.shield, color: Colors.white38, size: 36),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _teamName.toUpperCase(),
                  style: GoogleFonts.oswald(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (academyName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(academyName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (categoryShort.isNotEmpty) _chip(categoryShort),
                    if (groupLabel != null &&
                        groupLabel.isNotEmpty &&
                        groupLabel != 'SIN_GRUPO')
                      _chip('Grupo $groupLabel'),
                    if (points != null && points != 0) _chip('$points pts', highlight: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.brandTeal.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: highlight ? Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: highlight ? AppTheme.brandTeal : Colors.white70,
        ),
      ),
    );
  }

  Widget _playerTile(Map<String, dynamic> player) {
    final photo = widget.resolveMediaUrl((player['thumb'] ?? player['photo'] ?? '').toString());
    final number = (player['number'] ?? player['num'] ?? '—').toString();
    final name = (player['alias'] ?? player['name'] ?? 'Jugador').toString();
    final position = MatchHelpers.playerPositionsLabel(
      player,
      fallback: 'N/A',
    );
    final present = _playerIsPresent(player);
    final attValue = _attendanceValue(player);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: present
              ? AppTheme.success.withValues(alpha: 0.35)
              : const Color(0xFF334155).withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#$number',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.brandTeal,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.navyPrimary,
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: ClipOval(
              child: photo.isNotEmpty
                  ? Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white38, size: 22),
                    )
                  : const Icon(Icons.person, color: Colors.white38, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(position, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          if (attValue != null && attValue > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '$attValue PJ',
                style: GoogleFonts.shareTechMono(fontSize: 10, color: Colors.white38),
              ),
            ),
          Icon(
            present ? Icons.check_circle : Icons.cancel,
            color: present ? AppTheme.success : AppTheme.error,
            size: 20,
          ),
        ],
      ),
    );
  }
}
