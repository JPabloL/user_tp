import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/toast_service.dart';

class SearchPlayerSheet extends StatefulWidget {
  final ApiService api;
  final String userId;

  const SearchPlayerSheet({
    super.key,
    required this.api,
    required this.userId,
  });

  @override
  State<SearchPlayerSheet> createState() => _SearchPlayerSheetState();
}

class _SearchPlayerSheetState extends State<SearchPlayerSheet> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _foundPlayer;
  String _searchError = '';

  bool _prefMatches = true;
  bool _prefStats = true;
  bool _prefNews = false;
  bool _isFollowing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchPlayer() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundPlayer = null;
      _searchError = '';
    });

    try {
      final res = await widget.api.post('/getPlayerByUserName', {
        'userName': query,
      });

      if (res['found'] == true && res['player'] != null) {
        setState(() {
          _foundPlayer = res['player'];
        });
      } else {
        setState(() {
          _searchError = res['message'] ?? 'Jugador no encontrado.';
        });
      }
    } catch (e) {
      setState(() {
        _searchError = 'Error al buscar: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _followPlayer() async {
    if (_foundPlayer == null) return;
    
    setState(() => _isFollowing = true);
    
    try {
      final res = await widget.api.post('/followPlayer', {
        'userId': widget.userId,
        'playerId': _foundPlayer!['_id'] ?? _foundPlayer!['id'],
        'autoFollowTeams': true,
        'preferences': {
          'matches': _prefMatches,
          'stats': _prefStats,
          'news': _prefNews,
        }
      });
      
      if (res['status'] == 'ok') {
        ToastService.show(res['message'] ?? 'Comenzaste a seguir a este jugador');
        if (mounted) Navigator.pop(context, true); // Retorna true para recargar
      } else {
        ToastService.show(res['message'] ?? 'Error al seguir al jugador', isError: true);
      }
    } catch (e) {
      ToastService.show('Error al procesar la solicitud: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFollowing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUSCAR JUGADOR',
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(20), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // Search Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '@username',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.alternate_email, color: AppTheme.brandTeal),
                      filled: true,
                      fillColor: Colors.white.withAlpha(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _searchPlayer(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSearching ? null : _searchPlayer,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isSearching
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.navyPrimary, strokeWidth: 2))
                        : const Icon(Icons.search, color: AppTheme.navyPrimary),
                  ),
                ),
              ],
            ),
            
            if (_searchError.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_searchError, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],

            if (_foundPlayer != null) ...[
              const SizedBox(height: 24),
              // Player Card Mini
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.brandTeal.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white10,
                      backgroundImage: _foundPlayer!['photo'] != null && _foundPlayer!['photo'].toString().isNotEmpty
                          ? NetworkImage(_foundPlayer!['photo'])
                          : null,
                      child: _foundPlayer!['photo'] == null || _foundPlayer!['photo'].toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.white54)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_foundPlayer!['fullName'] ?? _foundPlayer!['name'] ?? 'Jugador').toString().toUpperCase(),
                            style: GoogleFonts.oswald(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${_foundPlayer!['userName']}',
                            style: const TextStyle(color: AppTheme.brandTeal, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (_foundPlayer!['teamsCount'] != null && _foundPlayer!['teamsCount'] > 0)
                            Text('${_foundPlayer!['teamsCount']} equipos activos', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('PREFERENCIAS DE SEGUIMIENTO', style: GoogleFonts.oswald(color: Colors.white54, fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              
              _buildPrefSwitch('🏆 Partidos y Resultados en vivo', _prefMatches, (v) => setState(() => _prefMatches = v)),
              _buildPrefSwitch('📊 Estadísticas y Hitos', _prefStats, (v) => setState(() => _prefStats = v)),
              _buildPrefSwitch('📰 Noticias y Avisos', _prefNews, (v) => setState(() => _prefNews = v)),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.brandTeal.withAlpha(50)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppTheme.brandTeal, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Al seguir a este jugador, también seguirás automáticamente sus equipos activos para no perderte nada.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isFollowing ? null : _followPlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandTeal,
                    foregroundColor: AppTheme.navyPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isFollowing
                      ? const CircularProgressIndicator(color: AppTheme.navyPrimary)
                      : Text(
                          'COMENZAR A SEGUIR',
                          style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrefSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.brandTeal,
            activeTrackColor: AppTheme.brandTeal.withAlpha(80),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }
}
