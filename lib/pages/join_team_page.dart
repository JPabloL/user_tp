import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/join_team_link.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import '../utils/team_request_helpers.dart';
import 'email_verification_page.dart';
import 'home_page.dart';
import 'login_page.dart';

class JoinTeamPage extends StatefulWidget {
  const JoinTeamPage({
    super.key,
    required this.api,
    required this.storage,
    this.teamToken,
  });

  static const String route = JoinTeamLink.route;

  final ApiService api;
  final StorageService storage;
  final String? teamToken;

  @override
  State<JoinTeamPage> createState() => _JoinTeamPageState();
}

class _JoinTeamPageState extends State<JoinTeamPage> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _academy;
  List<Map<String, dynamic>> _profiles = [];
  Map<String, List<Map<String, dynamic>>> _requestsByPlayerId = {};
  String _academyId = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = widget.teamToken ??
        JoinTeamLink.initialToken() ??
        await JoinTeamLink.readPending(widget.storage);

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'El enlace no incluye un equipo válido.';
      });
      return;
    }

    await JoinTeamLink.savePending(widget.storage, token);

    final session = await widget.storage.getJson(AppConfig.sessionKey);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (!JoinTeamLink.hasActiveSession(session) || firebaseUser == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        LoginPage.route,
        arguments: {'joinTeamToken': token},
      );
      return;
    }

    if (!firebaseUser.emailVerified) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(EmailVerificationPage.route);
      return;
    }

    await _loadData(token, session!);
  }

  Future<void> _loadData(String token, Map<String, dynamic> session) async {
    setState(() {
      _loading = true;
      _error = null;
      _token = token;
    });

    try {
      final academy = await widget.api.findAcademyByPublicKey(token);
      if (academy == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No encontramos un equipo con esa clave.';
        });
        return;
      }

      final res = await widget.api.getUserContextV2(session['uid'].toString());
      if (res['status'] != 'ok') {
        throw Exception('No se pudo cargar tu perfil');
      }

      final user = Map<String, dynamic>.from(res['user'] as Map? ?? {});
      _userId = (user['_id'] ?? user['id'] ?? session['id'] ?? '').toString();

      final dash = res['dashboard'];
      final rawProfiles = dash is Map
          ? (dash['profiles'] as List<dynamic>? ?? [])
          : <dynamic>[];

      final profiles = rawProfiles
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .where((p) => p['relation']?.toString() != 'followed')
          .toList();

      final academyId = TeamRequestHelpers.academyId(academy);
      final requestsByPlayer = <String, List<Map<String, dynamic>>>{};

      await Future.wait(
        profiles.map((profile) async {
          final playerId = TeamRequestHelpers.playerIdFromProfile(profile);
          if (playerId.isEmpty) return;
          try {
            final rawRequests = await widget.api.getMyRequests(playerId);
            requestsByPlayer[playerId] =
                TeamRequestHelpers.normalizePlayerRequests(rawRequests);
          } catch (_) {
            requestsByPlayer[playerId] = [];
          }
        }),
      );

      if (!mounted) return;
      setState(() {
        _academy = academy;
        _academyId = academyId;
        _profiles = profiles;
        _requestsByPlayerId = requestsByPlayer;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _resolveMediaUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://cuerposallimite.net$value';
    return 'https://cuerposallimite.net/nlff/resources/images/$value';
  }

  Map<String, dynamic> _playerPayload(Map<String, dynamic> profile) {
    final playerId =
        (profile['playerId'] ?? profile['id'] ?? profile['_id'] ?? '').toString();
    return {
      'id': playerId,
      'name': profile['name'],
      'userName': profile['userName'] ?? profile['alias'],
      'bd': profile['bd'],
      'alias': profile['alias'],
      'gender': profile['gender'],
      'thumb': profile['thumb'] ?? profile['photo'],
    };
  }

  Map<String, dynamic>? _existingRequestForProfile(Map<String, dynamic> profile) {
    final playerId = TeamRequestHelpers.playerIdFromProfile(profile);
    final requests = _requestsByPlayerId[playerId] ?? [];
    return TeamRequestHelpers.findExistingRequest(requests, _academyId);
  }

  TeamRequestStatus _requestStatusForProfile(Map<String, dynamic> profile) {
    return TeamRequestHelpers.statusForExisting(_existingRequestForProfile(profile));
  }

  Future<void> _resendExisting(Map<String, dynamic> existing) async {
    setState(() => _sending = true);
    try {
      final updated = Map<String, dynamic>.from(existing);
      updated['mood'] = 0;
      updated['origin'] = 'player';

      final resp = await widget.api.updateRequest(
        request: updated,
        userId: _userId,
      );

      if (resp['ok'] != true && resp['rev'] == null) {
        throw Exception('No se pudo reenviar la solicitud');
      }

      updated['_rev'] = resp['rev'];
      final playerId = (updated['player']?['id'] ?? '').toString();
      if (playerId.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(_requestsByPlayerId[playerId] ?? []);
        final index = list.indexWhere(
          (item) =>
              (item['_id'] ?? item['id'] ?? '').toString() ==
              (existing['_id'] ?? existing['id'] ?? '').toString(),
        );
        if (index >= 0) {
          list[index] = updated;
        } else {
          list.insert(0, updated);
        }
        _requestsByPlayerId[playerId] = list;
      }

      await JoinTeamLink.clearPending(widget.storage);
      if (!mounted) return;

      setState(() {});
      ToastService.show('Solicitud reactivada.');
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        'Ya existe una solicitud o hubo un error.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmAndSend(Map<String, dynamic> profile) async {
    final academy = _academy;
    if (academy == null) return;

    final status = _requestStatusForProfile(profile);
    final existing = _existingRequestForProfile(profile);

    if (status == TeamRequestStatus.pending) {
      ToastService.show(
        'Ya existe una solicitud pendiente para este equipo.',
        isError: true,
      );
      return;
    }

    if (status == TeamRequestStatus.accepted) {
      ToastService.show(
        'Este jugador ya fue aceptado en este equipo.',
        isError: true,
      );
      return;
    }

    if (status == TeamRequestStatus.canResend && existing != null) {
      final playerName = (profile['name'] ?? profile['alias'] ?? 'Jugador').toString();
      final teamName = (academy['name'] ?? 'equipo').toString();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.navySurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Reenviar solicitud',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '¿Reactivar la solicitud de $playerName para unirse a $teamName?',
            style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.brandTeal),
              child: const Text('Sí, reenviar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _resendExisting(existing);
      }
      return;
    }

    final playerName = (profile['name'] ?? profile['alias'] ?? 'Jugador').toString();
    final teamName = (academy['name'] ?? 'equipo').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirmar solicitud',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          '¿Enviar solicitud de $playerName para unirse a $teamName?',
          style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.brandTeal),
            child: const Text('Sí, enviar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      final player = _playerPayload(profile);
      if (player['id'].toString().isEmpty) {
        throw Exception('Perfil de jugador inválido');
      }

      final requestDoc = <String, dynamic>{
        'type': 'requestPlayer',
        'mood': 0,
        'origin': 'player',
        'player': player,
        'academy': {
          'id': academy['id'] ?? academy['_id'],
          'name': academy['name'],
          'thumb': academy['logo_url'] ?? academy['logo'],
        },
        'date': DateTime.now().toIso8601String(),
      };

      final resp = await widget.api.updateRequest(
        request: requestDoc,
        userId: _userId,
      );

      if (resp['ok'] != true && resp['rev'] == null) {
        throw Exception('No se pudo enviar la solicitud');
      }

      requestDoc['_id'] = resp['id'];
      requestDoc['_rev'] = resp['rev'];
      final playerId = player['id'].toString();
      final list = List<Map<String, dynamic>>.from(_requestsByPlayerId[playerId] ?? []);
      list.insert(0, requestDoc);
      _requestsByPlayerId[playerId] = list;

      await JoinTeamLink.clearPending(widget.storage);
      if (!mounted) return;

      ToastService.show('¡Solicitud enviada con éxito!');
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ToastService.show(
        'Ya existe una solicitud o hubo un error.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _skipInvitation() async {
    await JoinTeamLink.clearPending(widget.storage);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_sending) {
          _skipInvitation();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.navyPrimary,
        appBar: AppBar(
          backgroundColor: AppTheme.navyPrimary,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Cerrar',
            onPressed: _sending ? null : _skipInvitation,
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            'Unirse a equipo',
            style: GoogleFonts.oswald(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _sending ? null : _skipInvitation,
              child: Text(
                'Omitir',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.brandTeal))
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off_rounded, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed(LoginPage.route),
              child: const Text('Ir al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final academy = _academy!;
    final logo = _resolveMediaUrl((academy['logo_url'] ?? academy['logo'] ?? '').toString());
    final teamName = (academy['name'] ?? 'Equipo').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: logo.isNotEmpty
                      ? Image.network(
                          logo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _logoPlaceholder(),
                        )
                      : _logoPlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equipo invitado',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandTeal,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teamName,
                        style: GoogleFonts.oswald(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_token != null)
                        Text(
                          'Clave: $_token',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Selecciona el jugador',
            style: GoogleFonts.oswald(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige quién de tus jugadores gestionados enviará la solicitud a este equipo.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (_profiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'No tienes jugadores gestionados en esta cuenta. Agrega un perfil desde tu panel antes de enviar la solicitud.',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.45),
              ),
            )
          else
            ..._profiles.map(_buildPlayerTile),
          if (_sending)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.brandTeal),
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _sending ? null : _skipInvitation,
              child: Text(
                'Omitir por ahora',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Podrás usar el mismo enlace más tarde si cambias de opinión.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppTheme.navyElevated,
      child: const Icon(Icons.shield_outlined, color: AppTheme.textSecondary),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? profile['alias'] ?? 'Jugador').toString();
    final thumb = _resolveMediaUrl((profile['thumb'] ?? profile['photo'] ?? '').toString());
    final verified = profile['identity_status']?.toString() == 'verified';
    final status = _requestStatusForProfile(profile);
    final canInteract = verified &&
        !_sending &&
        status != TeamRequestStatus.pending &&
        status != TeamRequestStatus.accepted;

    Color subtitleColor = AppTheme.brandTeal;
    if (!verified) {
      subtitleColor = Colors.redAccent;
    } else if (status == TeamRequestStatus.pending) {
      subtitleColor = const Color(0xFFFFD600);
    } else if (status == TeamRequestStatus.accepted) {
      subtitleColor = AppTheme.brandTeal;
    } else if (status == TeamRequestStatus.canResend) {
      subtitleColor = Colors.white70;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canInteract ? () => _confirmAndSend(profile) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !verified
                    ? Colors.redAccent.withValues(alpha: 0.35)
                    : status == TeamRequestStatus.pending
                        ? const Color(0xFFFFD600).withValues(alpha: 0.35)
                        : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.navyElevated,
                  backgroundImage: thumb.isNotEmpty ? NetworkImage(thumb) : null,
                  child: thumb.isEmpty
                      ? const Icon(Icons.person, color: AppTheme.textSecondary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        !verified
                            ? 'Verifica la identidad antes de solicitar'
                            : TeamRequestHelpers.statusLabel(status),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  !verified
                      ? Icons.lock_outline
                      : status == TeamRequestStatus.canResend
                          ? Icons.refresh_rounded
                          : status == TeamRequestStatus.pending ||
                                  status == TeamRequestStatus.accepted
                              ? Icons.info_outline_rounded
                              : Icons.chevron_right_rounded,
                  color: !verified ? Colors.redAccent : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
