import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../utils/navigation_helpers.dart';

class PlayerStatDetailRouteArgs {
  final Map<String, dynamic> player;
  final Map<String, dynamic> team;

  PlayerStatDetailRouteArgs({required this.player, required this.team});
}

class PlayerStatDetailPage extends StatefulWidget {
  static const String route = '/player_stat_detail';
  final ApiService api;

  const PlayerStatDetailPage({Key? key, required this.api}) : super(key: key);

  @override
  State<PlayerStatDetailPage> createState() => _PlayerStatDetailPageState();
}

class _PlayerStatDetailPageState extends State<PlayerStatDetailPage> {
  static const Color brandBg = Color(0xFF0F172A);
  static const Color brandSurface = Color(0xFF1E293B);
  static const Color brandPrimary = Color(0xFF2DD4BF);
  static const Color visitColor = Color(0xFFE040FB);
  static const Color textMuted = Colors.white54;

  Map<String, dynamic>? player;
  Map<String, dynamic>? team;
  bool isLoading = true;
  Map<String, dynamic>? _statsData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (player == null && team == null) {
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      if (rawArgs is PlayerStatDetailRouteArgs) {
        player = rawArgs.player;
        team = rawArgs.team;
      } else if (rawArgs is Map<String, dynamic>) {
        player = rawArgs['player'] as Map<String, dynamic>?;
        team = rawArgs['team'] as Map<String, dynamic>?;
      }
      
      if (player != null && team != null) {
        _fetchPlayerStats();
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchPlayerStats() async {
    final pId = (player!['_id'] ?? player!['id'] ?? '').toString();
    final tId = (team!['_id'] ?? team!['id'] ?? '').toString();

    if (pId.isEmpty || tId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final res = await widget.api.post('/getPlayerActionsSummary', {
        'token': '3es_ldo5%4d',
        'playerId': pId,
        'teamId': tId,
      });

      if (res != null && res['status'] == 'ok') {
        setState(() {
          _statsData = res;
        });
      } else {
        setState(() {
          _statsData = null;
        });
      }
    } catch (e) {
      setState(() {
        _statsData = null;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  String _resolveMedia(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return 'https://cuerposallimite.net$url';
    return 'https://cuerposallimite.net/nlff/resources/images/$url';
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (player == null || team == null) {
      return const Scaffold(backgroundColor: brandBg, body: Center(child: Text('Faltan argumentos', style: TextStyle(color: Colors.white))));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: brandBg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF151515),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => popOrGoHome(context),
          ),
          title: Text('ESTADÍSTICAS DEL JUGADOR', style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, letterSpacing: 1)),
        ),
        body: Column(
          children: [
            _buildPlayerHeader(),
            const TabBar(
              indicatorColor: brandPrimary,
              labelColor: brandPrimary,
              unselectedLabelColor: textMuted,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5, fontFamily: 'Oswald'),
              tabs: [
                Tab(text: 'REGULAR'),
                Tab(text: 'PLAYOFFS'),
                Tab(text: 'DETALLE'),
              ],
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: brandPrimary))
                  : _statsData == null
                      ? Center(child: Text('No se encontraron datos', style: GoogleFonts.inter(color: textMuted)))
                      : TabBarView(
                          children: [
                            _buildSummaryTab(_statsData?['regular']?['summary']),
                            _buildSummaryTab(_statsData?['playoffs']?['summary']),
                            _buildDetailTab(_statsData?['season']?['journeys'] as List?),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader() {
    final thumb = (player!['thumb'] ?? '').toString();
    final name = (player!['name'] ?? '').toString();
    final alias = (player!['alias'] ?? name).toString().toUpperCase();
    final number = (player!['number'] ?? '-').toString();
    
    final tName = (team!['name'] ?? '').toString().toUpperCase();
    final tLogo = (team!['logo'] ?? team!['thumb'] ?? '').toString();

    final avatarUrl = _resolveMedia(thumb);
    final logoUrl = _resolveMedia(tLogo);

    return Container(
      width: double.infinity,
      color: const Color(0xFF151515),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar + Team Badge
          Stack(
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: brandPrimary, width: 2)),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.person, size: 40, color: Colors.white24))
                      : const Icon(Icons.person, size: 40, color: Colors.white24),
                ),
              ),
              if (logoUrl.isNotEmpty)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF151515), width: 2)),
                    child: ClipOval(
                      child: Image.network(logoUrl, fit: BoxFit.contain, errorBuilder: (_,__,___) => const SizedBox()),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Texts
          Text(alias, style: GoogleFonts.oswald(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (name.isNotEmpty && name.toUpperCase() != alias) ...[
            const SizedBox(height: 2),
            Text(name.toUpperCase(), style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: brandPrimary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4), border: Border.all(color: brandPrimary)),
                child: Text('#$number', style: GoogleFonts.oswald(color: brandPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(tName, style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryTab(dynamic summary) {
    if (summary == null || summary is! Map) {
      return Center(child: Text('Sin estadísticas', style: GoogleFonts.inter(color: textMuted)));
    }

    final pases = int.tryParse(summary['pass']?['total']?.toString() ?? '0') ?? 0;
    final ofensa = int.tryParse(summary['offensivePoints']?.toString() ?? '0') ?? 0;
    final inter = int.tryParse(summary['inter']?['total']?.toString() ?? '0') ?? 0;
    final sack = int.tryParse(summary['sack']?['total']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatCard('PASES COMPLETOS', pases, Icons.sports_football, Colors.white),
          const SizedBox(height: 12),
          _buildStatCard('PUNTOS OFENSA', ofensa, Icons.local_fire_department, brandPrimary),
          const SizedBox(height: 12),
          _buildStatCard('INTERCEPCIONES', inter, Icons.shield_outlined, Colors.white),
          const SizedBox(height: 12),
          _buildStatCard('SACKS', sack, Icons.flash_on, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.oswald(color: textMuted, fontSize: 14, letterSpacing: 1)),
              Text('$value', style: GoogleFonts.oswald(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.2)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDetailTab(List<dynamic>? journeys) {
    if (journeys == null || journeys.isEmpty) {
      return Center(child: Text('Sin jornadas', style: GoogleFonts.inter(color: textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: journeys.length,
      itemBuilder: (ctx, i) {
        final j = journeys[i];
        if (j is! Map) return const SizedBox();

        final rawJourney = (j['journey'] ?? '').toString();
        final isPlayoff = rawJourney.toLowerCase().contains('final');
        final displayTitle = isPlayoff ? rawJourney.toUpperCase() : 'JORNADA ${rawJourney.toUpperCase()}';

        final summary = j['summary'] ?? {};
        final pases = int.tryParse(summary['pass']?['total']?.toString() ?? '0') ?? 0;
        final ofensa = int.tryParse(summary['offensivePoints']?.toString() ?? '0') ?? 0;
        final inter = int.tryParse(summary['inter']?['total']?.toString() ?? '0') ?? 0;
        final sack = int.tryParse(summary['sack']?['total']?.toString() ?? '0') ?? 0;

        final matches = j['matches'] as List? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: brandPrimary,
              collapsedIconColor: textMuted,
              title: Text(displayTitle, style: GoogleFonts.oswald(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              subtitle: Text('Pases: $pases | Ptos Ofensa: $ofensa | Inter: $inter | Sacks: $sack', style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
              children: matches.map((m) => _buildMatchDetail(m)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatchDetail(dynamic matchItem) {
    if (matchItem is! Map) return const SizedBox();

    final match = matchItem['match'] ?? {};
    final summary = matchItem['summary'] ?? {};
    final ownTeam = match['ownTeam'] ?? {};
    final rival = match['rival'] ?? {};

    // OwnScore cascade
    final ownScoreStr = (ownTeam['points'] ?? ownTeam['score'] ?? match['scoreHome'] ?? match['pointsHome'] ?? match['score'] ?? '0').toString();
    final ownScore = int.tryParse(ownScoreStr) ?? 0;

    // RivalScore cascade
    final rivalScoreStr = (rival['points'] ?? rival['score'] ?? match['scoreVisitor'] ?? match['pointsVisitor'] ?? match['scoreRival'] ?? '0').toString();
    final rivalScore = int.tryParse(rivalScoreStr) ?? 0;

    final ownName = (ownTeam['name'] ?? 'Local').toString();
    final ownLogo = _resolveMedia((ownTeam['logo'] ?? ownTeam['thumb'] ?? '').toString());

    final rivalName = (rival['name'] ?? 'Visita').toString();
    final rivalLogo = _resolveMedia((rival['logo'] ?? rival['thumb'] ?? '').toString());

    // Stats
    final pases = int.tryParse(summary['pass']?['total']?.toString() ?? '0') ?? 0;
    final ofensa = int.tryParse(summary['offensivePoints']?.toString() ?? '0') ?? 0;
    final inter = int.tryParse(summary['inter']?['total']?.toString() ?? '0') ?? 0;
    final sack = int.tryParse(summary['sack']?['total']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: Text(ownName, style: GoogleFonts.oswald(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    _buildMiniLogo(ownLogo),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$ownScore - $rivalScore', style: GoogleFonts.oswald(color: brandPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildMiniLogo(rivalLogo),
                    const SizedBox(width: 8),
                    Flexible(child: Text(rivalName, style: GoogleFonts.oswald(color: textMuted, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.left, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat('Pases', pases),
                _buildMiniStat('Ptos Ofensa', ofensa),
                _buildMiniStat('Inter', inter),
                _buildMiniStat('Sacks', sack),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniLogo(String url) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      child: ClipOval(
        child: url.isNotEmpty
            ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.shield, size: 12, color: Colors.white24))
            : const Icon(Icons.shield, size: 12, color: Colors.white24),
      ),
    );
  }

  Widget _buildMiniStat(String label, int value) {
    return Column(
      children: [
        Text('$value', style: GoogleFonts.oswald(color: brandPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: textMuted, fontSize: 10)),
      ],
    );
  }
}
