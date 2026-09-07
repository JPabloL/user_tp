import 'dart:math';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../pages/home_page.dart';
import '../pages/join_team_page.dart';
import '../services/api_service.dart';
import '../services/join_team_link.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import 'email_verification_page.dart';
import '../config/theme.dart';
import '../utils/user_players_debug_log.dart';

enum LoginView { enter, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.storage});

  static const String route = '/login';

  final ApiService api;
  final StorageService storage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  LoginView view = LoginView.enter;

  // --- ANIMACIONES UI ---
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  // --- CONTROLADORES ---
  final _nameCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passCompareCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // --- ESTADO DE ERRORES VISUALES ---
  Map<String, String?> _formErrors = {};

  // --- ESTADO LÓGICO ---
  bool passCheck = true;
  bool recover = false;
  bool isLoading = false;
  String? _joinTeamToken;
  bool _joinIntentLoaded = false;

  // --- FORMATTERS ---
  var phoneMaskFormatter = MaskTextInputFormatter(
    mask: '##########',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final noSpaceFormatter = FilteringTextInputFormatter.deny(RegExp(r'\s'));

  @override
  void initState() {
    super.initState();
    _checkActiveSession();

    // Animaciones de Entrada
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad),
    );
    _animCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_joinIntentLoaded) return;
    _joinIntentLoaded = true;
    _loadJoinTeamIntent();
  }

  Future<void> _loadJoinTeamIntent() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final fromArgs = JoinTeamLink.tokenFromRouteSettings(args);
    if (fromArgs != null) {
      await JoinTeamLink.savePending(widget.storage, fromArgs);
      if (mounted) setState(() => _joinTeamToken = fromArgs);
      return;
    }
    final pending = await JoinTeamLink.readPending(widget.storage);
    if (mounted && pending != null) {
      setState(() => _joinTeamToken = pending);
    }
  }

  Future<void> _checkActiveSession() async {
    _setLoading(true);
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first;
      if (user != null) {
        final session = await widget.storage.getJson(AppConfig.sessionKey);
        if (session != null && session['id'] != null) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(HomePage.route);
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _mailCtrl.dispose();
    _passCtrl.dispose();
    _passCompareCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_formErrors.containsKey(field)) {
      setState(() {
        _formErrors.remove(field);
      });
    }
  }

  // =========================================================
  //      LÓGICA DE NEGOCIO (FIREBASE + API V2)
  // =========================================================

  Future<void> login() async {
    if (!_cleanAndValidateEmail()) return;
    if (_passCtrl.text.isEmpty) {
      setState(() => _formErrors['pass'] = 'Ingresa tu contraseña');
      return;
    }

    _setLoading(true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _mailCtrl.text,
        password: _passCtrl.text,
      );
      await finalizeLogin(credential.user!);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'invalid-credential') {
        await attemptLegacyMigration();
      } else {
        _setLoading(false);
        _toast(translateError(error.code), isError: true);
      }
    } catch (_) {
      _setLoading(false);
      _toast('Error de acceso', isError: true);
    }
  }

  Future<void> attemptLegacyMigration() async {
    try {
      final res = await widget.api.migrateUser(_mailCtrl.text, _passCtrl.text);
      if (res['status'] == 'ok' && res['token'] != null) {
        final credential = await FirebaseAuth.instance.signInWithCustomToken(
          res['token'] as String,
        );
        await finalizeLogin(credential.user!);
      } else {
        _setLoading(false);
        _toast('Usuario o contraseña incorrectos', isError: true);
      }
    } catch (e, st) {
      print('Error in attemptLegacyMigration: $e');
      print(st);
      _setLoading(false);
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }
      _toast('Error: $errorMsg', isError: true);
    }
  }

  Future<void> register() async {
    if (!_cleanAndValidateEmail()) return;

    Map<String, String?> newErrors = {};
    bool isValid = true;

    if (_nameCtrl.text.trim().isEmpty) {
      newErrors['name'] = 'Nombre obligatorio';
      isValid = false;
    }
    if (_phoneCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().length < 10) {
      newErrors['phone'] = 'Teléfono inválido (10 dígitos)';
      isValid = false;
    }
    if (_passCtrl.text.isEmpty) {
      newErrors['pass'] = 'Crea una contraseña';
      isValid = false;
    } else if (_passCtrl.text.length < 6) {
      newErrors['pass'] = 'Mínimo 6 caracteres';
      isValid = false;
    }
    if (!passCheck || _passCtrl.text != _passCompareCtrl.text) {
      newErrors['passCompare'] = 'No coinciden';
      isValid = false;
    }

    if (!isValid) {
      setState(() => _formErrors = newErrors);
      _toast('Corrige los errores para continuar', isError: true);
      return;
    }

    _setLoading(true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _mailCtrl.text,
        password: _passCtrl.text,
      );

      await credential.user!.sendEmailVerification();

      final userData = <String, dynamic>{
        'uid': credential.user!.uid,
        'name': _nameCtrl.text.trim(),
        'mail': _mailCtrl.text,
        'phone': _phoneCtrl.text.trim(),
      };

      await widget.api.registerUserV2(userData);
      await finalizeLogin(credential.user!);
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _toast(translateError(e.code), isError: true);
    } catch (_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }
      _setLoading(false);
      _toast('Error al guardar perfil', isError: true);
    }
  }

  Future<void> finalizeLogin(User firebaseUser) async {
    try {
      final res = await widget.api.getUserContextV2(firebaseUser.uid);
      _setLoading(false);
      if (res['status'] == 'ok' && res['user'] != null) {
        logUserPlayersContext(res, source: 'login');
        final dbUser = res['user'] as Map<String, dynamic>;
        final roles = (res['roles'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final token = await firebaseUser.getIdToken();

        final sessionData = <String, dynamic>{
          'id': dbUser['_id'],
          'uid': firebaseUser.uid,
          'name': dbUser['name'],
          'mail': dbUser['mail'],
          'avatar': dbUser['avatar'],
          'roles': roles,
          'shortcuts': res['shortcuts'],
          'fcm_token': res['fcm_token'],
          'token': token,
        };
        final myPlayer = res['myPlayerProfile'];
        if (myPlayer is Map) {
          final myPlayerId = (myPlayer['playerId'] ??
                  myPlayer['id'] ??
                  myPlayer['_id'] ??
                  '')
              .toString();
          if (myPlayerId.isNotEmpty) {
            sessionData['myPlayerId'] = myPlayerId;
          }
        }
        await widget.storage.setJson(AppConfig.sessionKey, sessionData);
        if (!mounted) return;

        if (!firebaseUser.emailVerified) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            EmailVerificationPage.route,
            (_) => false,
          );
          return;
        }

        final pendingJoin = await JoinTeamLink.readPending(widget.storage);
        if (pendingJoin != null && pendingJoin.isNotEmpty) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            JoinTeamPage.route,
            (_) => false,
            arguments: {'token': pendingJoin},
          );
          return;
        }

        final firstName = (dbUser['name']?.toString() ?? 'Usuario').split(' ').first;
        _toast('Bienvenido $firstName');
        _goToNextByProfile(dbUser, roles);
      } else {
        _toast('Error al cargar perfil. Intenta de nuevo.', isError: true);
      }
    } catch (e, st) {
      print('Error in finalizeLogin: $e');
      print(st);
      _setLoading(false);
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }
      _toast('Error: $errorMsg', isError: true);
    }
  }

  void _goToNextByProfile(Map<String, dynamic> dbUser, Map<String, dynamic> roles) {
    final rawStep = dbUser['verification_step']?.toString();
    final currentStep = int.tryParse(rawStep ?? '0') ?? 0;
    final isPlayer = roles['isPlayer'] == true;
    final isTutor = roles['isTutor'] == true;

    final playerIncomplete = isPlayer && currentStep < 3;
    final tutorIncomplete = isTutor && currentStep < 2;
    final newUser = (!isPlayer && !isTutor) || currentStep == 0;

    if (playerIncomplete || tutorIncomplete || newUser) {
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    }
  }

  Future<void> sendRecovery() async {
    if (_mailCtrl.text.trim().isEmpty) {
      setState(() => _formErrors['email'] = 'Ingresa tu correo');
      return;
    }
    if (!_cleanAndValidateEmail()) return;

    final email = _mailCtrl.text.trim().toLowerCase();
    _setLoading(true);
    try {
      final usesFirebase = await _accountUsesFirebase(email);
      if (!usesFirebase) {
        final isLegacy = await widget.api.hasLegacyTutorAccount(email);
        _setLoading(false);
        if (!mounted) return;
        if (isLegacy) {
          await _showLegacyRecoveryDialog(email);
          return;
        }
      }

      await _sendFirebasePasswordReset(email);
    } catch (e) {
      _setLoading(false);
      if (e is FirebaseAuthException) {
        _toast(translateError(e.code), isError: true);
      } else {
        _toast('No se pudo procesar la recuperación. Intenta de nuevo.', isError: true);
      }
    }
  }

  Future<bool> _accountUsesFirebase(String email) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendFirebasePasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    _toast('Correo de recuperación enviado');
    setState(() {
      recover = false;
      isLoading = false;
    });
  }

  Future<void> _requestLegacyRecoverySupport(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      _toast('Ingresa el correo de tu cuenta anterior', isError: true);
      return;
    }

    final payload = <String, dynamic>{
      'origin': 'user',
      'requesterId': normalizedEmail,
      'importance': 'media',
      'category': 'account',
      'issueType': 'password_recovery',
      'subject': 'Recuperación de cuenta anterior',
      'description':
          'Solicito ayuda para recuperar el acceso a mi cuenta del sistema anterior. '
          'Correo reportado: $normalizedEmail.',
      'userMessage':
          'No tengo acceso al correo registrado o no puedo recuperar la contraseña de mi cuenta anterior.',
      'source': <String, dynamic>{
        'module': 'account',
        'feature': 'legacy_recovery',
        'function': 'requestLegacyAccountRecovery',
        'screen': 'LoginPage',
        'action': 'create_legacy_recovery_ticket',
      },
      'relatedEntities': <String, dynamic>{
        'legacyEmail': normalizedEmail,
      },
      'metadata': <String, dynamic>{
        'requestType': 'legacy_account_recovery',
        'reportedEmail': normalizedEmail,
      },
      'channel': 'in_app',
      'tags': <String>[
        'password-recovery',
        'legacy-account',
        'login',
      ],
    };

    final res = await widget.api.createSupportTicket(ticketData: payload);

    if (res['status'] == 'active_ticket_exists') {
      _toast('Ya tienes un ticket en progreso para esta solicitud.', isError: true);
      return;
    }

    if (res['status'] == 'error' || res['ok'] == false) {
      throw Exception(res['message'] ?? 'Error al crear el ticket');
    }

    _toast('Ticket de soporte creado. Te contactaremos pronto.');
  }

  Future<void> _showLegacyRecoveryDialog(String initialEmail) async {
    final legacyEmailCtrl = TextEditingController(text: initialEmail);
    final legacyPasswordCtrl = TextEditingController();
    bool sending = false;
    bool hasPassword = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendLegacyPassword() async {
              final email = legacyEmailCtrl.text.trim().toLowerCase();
              if (email.isEmpty) {
                _toast('Ingresa el correo de tu cuenta anterior', isError: true);
                return;
              }

              setDialogState(() => sending = true);
              try {
                final res = await widget.api.sendMailRecoverTptutor(email: email);
                final status = res['status']?.toString() ?? '';

                if (status == 'firebase_required') {
                  Navigator.of(dialogContext).pop();
                  _setLoading(true);
                  await _sendFirebasePasswordReset(email);
                  return;
                }

                if (status == 'error' ||
                    status == 'not_found' ||
                    res['ok'] == false) {
                  throw Exception(res['message'] ?? 'No se encontró cuenta con ese correo');
                }

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                _toast('Contraseña enviada a tu correo. Revisa tu bandeja de entrada.');
                if (mounted) {
                  setState(() {
                    recover = false;
                    _mailCtrl.text = email;
                  });
                }
              } catch (e) {
                final msg = e.toString().replaceFirst('Exception: ', '');
                _toast(msg, isError: true);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => sending = false);
                }
              }
            }

            Future<void> requestLegacyRecoverySupport() async {
              final email = legacyEmailCtrl.text.trim().toLowerCase();
              if (email.isEmpty) {
                _toast('Ingresa el correo de tu cuenta anterior', isError: true);
                return;
              }

              setDialogState(() => sending = true);
              try {
                await _requestLegacyRecoverySupport(email);
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  setState(() {
                    recover = false;
                    _mailCtrl.text = email;
                  });
                }
              } catch (e) {
                final msg = e.toString().replaceFirst('Exception: ', '');
                _toast(msg, isError: true);
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => sending = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppTheme.navySurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              title: Text(
                'Cuenta anterior',
                style: GoogleFonts.oswald(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detectamos una cuenta del sistema anterior (sin Firebase). '
                      'Confirma el correo registrado y te enviaremos la contraseña. '
                      'Luego podrás iniciar sesión y el sistema migrará tu cuenta automáticamente.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: legacyEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Correo de la cuenta anterior',
                        labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.navyElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: legacyPasswordCtrl,
                      obscureText: true,
                      onChanged: (value) {
                        setDialogState(() => hasPassword = value.trim().isNotEmpty);
                      },
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Contraseña (si ya la recuerdas)',
                        labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.navyElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si olvidaste la contraseña, usa el botón de abajo para recibirla por correo.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: sending ? null : requestLegacyRecoverySupport,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          textStyle: GoogleFonts.inter(
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('¿No tienes acceso al correo? Contactar a Soporte'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'CANCELAR',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasPassword)
                  TextButton(
                    onPressed: sending
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                            _mailCtrl.text = legacyEmailCtrl.text.trim().toLowerCase();
                            _passCtrl.text = legacyPasswordCtrl.text;
                            setState(() => recover = false);
                            login();
                          },
                    child: Text(
                      'INICIAR SESIÓN',
                      style: GoogleFonts.inter(
                        color: AppTheme.brandTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: sending ? null : sendLegacyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandTeal,
                    foregroundColor: AppTheme.navyPrimary,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.navyPrimary,
                          ),
                        )
                      : Text(
                          'ENVIAR CONTRASEÑA',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    legacyEmailCtrl.dispose();
    legacyPasswordCtrl.dispose();
  }

  void compareText() {
    setState(() {
      passCheck = _passCtrl.text == _passCompareCtrl.text;
      if (passCheck) {
        _clearError('passCompare');
      } else {
        _formErrors['passCompare'] = 'No coinciden';
      }
    });
  }

  String translateError(String code) {
    if (code == 'email-already-in-use') return 'El correo ya está registrado';
    if (code == 'weak-password') return 'La contraseña es muy débil';
    if (code == 'invalid-email') return 'Correo inválido';
    return 'Error de acceso';
  }

  bool _cleanAndValidateEmail() {
    if (_mailCtrl.text.trim().isEmpty) {
      setState(() => _formErrors['email'] = 'El correo es obligatorio');
      return false;
    }
    final cleaned = _mailCtrl.text.replaceAll(RegExp(r'\s'), '').toLowerCase();
    _mailCtrl.text = cleaned;

    final emailRegex = RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$');
    if (!emailRegex.hasMatch(cleaned)) {
      setState(() => _formErrors['email'] = 'Formato de correo inválido');
      return false;
    }
    _clearError('email');
    return true;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(message, isError: isError);
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => isLoading = value);
  }

  // =========================================================
  //      UI LAYOUT (REDISEÑO VISUAL ESTILO STEALTH)
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyPrimary,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 900;

          return Stack(
            children: [
              // 1. Capa Yardas (Estilo Técnico)
              Positioned.fill(child: _FieldMarkings(isDesktop: isDesktop)),
              // 2. Capa Rutas (Animación de fondo)
              const Positioned.fill(child: _PlaybookBackground()),

              // Logo gráfico en la esquina superior derecha
              Positioned(
                top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top + 20 : 40,
                right: 32,
                child: Image.asset(
                  'assets/images/logo_icon.png',
                  height: isDesktop ? 64 : 54,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.bolt, color: AppTheme.brandTeal, size: isDesktop ? 64 : 54),
                ),
              ),

              // 3. Contenido Principal
              SafeArea(
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: _buildMainContent(constraints, isDesktop),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BoxConstraints constraints, bool isDesktop) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              constraints.maxHeight -
              MediaQuery.of(context).padding.top -
              MediaQuery.of(context).padding.bottom,
        ),
        child: Center(
          child: Container(
            width: isDesktop ? 1100 : double.infinity,
            padding: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 48)
                : const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(true),
              const SizedBox(height: 64),
              _buildVersionTag(),
            ],
          ),
        ),
        const SizedBox(width: 80),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildFormContent()],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildModernHeader(false),
        const SizedBox(height: 40),
        _buildFormContent(),
        const SizedBox(height: 40),
        Center(child: _buildVersionTag()),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- WIDGETS DE UI STEALTH ---

  Widget _buildModernHeader(bool isDesktop) {
    bool isRegistering = view == LoginView.register;
    String subtitle = recover
        ? 'Enviaremos un enlace de recuperación o te ayudaremos con tu cuenta anterior.'
        : (isRegistering
            ? 'Registra una cuenta nueva si aún no tienes perfil.'
            : '');

    double screenWidth = MediaQuery.of(context).size.width;
    double logoWidth = isDesktop ? screenWidth * 0.15 : screenWidth * 0.50;

    if (!isRegistering && !recover) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: logoWidth,
                  child: Image.asset(
                    'assets/images/logo_text.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Text(
                      'TOCHITO PRO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                        fontSize: isDesktop ? 80 : 64,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'JUGADOR / TUTOR',
                    style: GoogleFonts.oswald(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    String title = recover ? 'RECUPERAR' : 'CREAR\nPERFIL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.oswald(
            fontSize: isDesktop ? 90 : 64,
            height: 0.9,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: isDesktop ? 60 : 50,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.brandTeal,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: isDesktop ? 16 : 14,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionTag() {
    return Text(
      "Portal de jugador y/o tutor",
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: AppTheme.textSecondary.withValues(alpha: 0.5),
      ),
    );
  }

  Future<void> _skipJoinTeamInvitation() async {
    await JoinTeamLink.clearPending(widget.storage);
    if (mounted) {
      setState(() => _joinTeamToken = null);
    }
  }

  Widget _buildJoinTeamBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.group_add_rounded, color: AppTheme.brandTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitación a un equipo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para enviar la solicitud al equipo debes entrar a tu cuenta. Si ya tienes perfil de tutor o jugador, inicia sesión con tu correo y contraseña. Si eres nuevo, crea una cuenta y después podrás elegir qué jugador enviará la solicitud.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _skipJoinTeamInvitation,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Omitir por ahora',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandTeal,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.brandTeal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar invitación',
            onPressed: _skipJoinTeamInvitation,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthGuidance() {
    final bool isRegistering = view == LoginView.register;

    final String title = isRegistering
        ? '¿Ya tienes cuenta?'
        : '¿Cómo entrar?';
    final String body = isRegistering
        ? 'Si ya eres tutor o jugador, no crees otra cuenta. Vuelve a iniciar sesión con tu correo y contraseña actuales.'
        : 'Si ya tienes una cuenta creada de jugador o de tutor, usa ese mismo correo y contraseña que registraste para iniciar sesión.\n\n¿Eres nuevo? Pulsa «Crear cuenta nueva» más abajo.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRegistering ? Icons.login_rounded : Icons.info_outline_rounded,
            color: AppTheme.brandTeal,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    bool isRegistering = view == LoginView.register;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!recover) ...[
          if (_joinTeamToken != null) ...[
            _buildJoinTeamBanner(),
            const SizedBox(height: 24),
          ] else ...[
            _buildAuthGuidance(),
            const SizedBox(height: 24),
          ],
        ],
        if (isRegistering) ...[
          _TacticalInput(
            label: 'NOMBRE COMPLETO',
            controller: _nameCtrl,
            hint: 'Ej. Juan Pérez',
            errorText: _formErrors['name'],
            onChanged: (_) => _clearError('name'),
          ),
          const SizedBox(height: 20),
          _TacticalInput(
            label: 'TELÉFONO MÓVIL',
            controller: _phoneCtrl,
            isPhone: true,
            hint: '10 dígitos',
            maskFormatter: phoneMaskFormatter,
            errorText: _formErrors['phone'],
            onChanged: (_) => _clearError('phone'),
          ),
          const SizedBox(height: 20),
        ],

        _TacticalInput(
          label: 'CORREO ELECTRÓNICO',
          controller: _mailCtrl,
          isEmail: true,
          hint: 'usuario@email.com',
          errorText: _formErrors['email'],
          formatters: [noSpaceFormatter],
          onChanged: (_) => _clearError('email'),
        ),
        const SizedBox(height: 20),

        if (!recover) ...[
          _TacticalInput(
            label: 'CONTRASEÑA',
            controller: _passCtrl,
            isPass: true,
            hint: '••••••••',
            errorText: _formErrors['pass'],
            formatters: [noSpaceFormatter],
            onChanged: (val) {
              _clearError('pass');
              if (isRegistering) compareText();
            },
          ),
          const SizedBox(height: 20),
        ],

        if (isRegistering) ...[
          _TacticalInput(
            label: 'CONFIRMAR CONTRASEÑA',
            controller: _passCompareCtrl,
            isPass: true,
            hint: 'Repite tu contraseña',
            errorText: _formErrors['passCompare'],
            formatters: [noSpaceFormatter],
            onChanged: (val) => compareText(),
          ),
          if (!passCheck && !_formErrors.containsKey('passCompare'))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                "Las contraseñas no coinciden",
                style: GoogleFonts.inter(
                  color: AppTheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 32),
        _buildActionButtons(),
        const SizedBox(height: 32),
        _buildFooterLinks(),
      ],
    );
  }

  Widget _buildActionButtons() {
    bool isRegistering = view == LoginView.register;
    String mainText = recover
        ? 'ENVIAR ENLACE'
        : (isRegistering ? 'REGISTRARME' : 'ACCEDER');

    return Column(
      children: [
        SizedBox(
          height: 52,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : (recover ? sendRecovery : (isRegistering ? register : login)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandTeal,
              foregroundColor: AppTheme.navyPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.navyPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        mainText,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                if (!isLoading) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: AppTheme.navyPrimary, size: 18),
                ],
              ],
            ),
          ),
        ),

        if (!recover) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                view = isRegistering ? LoginView.enter : LoginView.register;
                _formErrors.clear();
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 52,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppTheme.brandTeal.withOpacity(0.3), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRegistering ? Icons.login : Icons.person_add,
                    color: AppTheme.brandTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isRegistering ? "YA TENGO CUENTA" : "CREAR CUENTA NUEVA",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandTeal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterLinks() {
    bool isRegistering = view == LoginView.register;
    if (recover) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              recover = false;
              _formErrors.clear();
            });
          },
          icon: const Icon(Icons.arrow_back, size: 16, color: AppTheme.textPrimary),
          label: Text(
            "REGRESAR AL LOGIN",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      );
    }

    if (!isRegistering) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              recover = true;
              _formErrors.clear();
            });
          },
          child: Text(
            "¿Olvidaste tu contraseña?",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// =========================================================
// INPUT TÁCTICO (STEALTH STYLE)
// =========================================================

class _TacticalInput extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isPass;
  final bool isEmail;
  final bool isPhone;
  final Function(String)? onChanged;
  final MaskTextInputFormatter? maskFormatter;
  final String? errorText;
  final List<TextInputFormatter>? formatters;

  const _TacticalInput({
    required this.label,
    required this.controller,
    this.hint,
    this.isPass = false,
    this.isEmail = false,
    this.isPhone = false,
    this.onChanged,
    this.maskFormatter,
    this.errorText,
    this.formatters,
  });

  @override
  State<_TacticalInput> createState() => _TacticalInputState();
}

class _TacticalInputState extends State<_TacticalInput> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null;
    final Color borderColor = hasError
        ? AppTheme.error
        : (_hasFocus ? AppTheme.brandTeal : AppTheme.navyElevated);
    final Color bgColor = AppTheme.navySurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: hasError ? AppTheme.error : AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: AppTheme.brandTeal.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPass,
            keyboardType: widget.isEmail
                ? TextInputType.emailAddress
                : (widget.isPhone ? TextInputType.phone : TextInputType.text),
            inputFormatters: [
              if (widget.isPhone && widget.maskFormatter != null) widget.maskFormatter!,
              if (widget.formatters != null) ...widget.formatters!,
            ],
            onChanged: widget.onChanged,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: AppTheme.brandTeal,
            decoration: InputDecoration(
              filled: false,
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 12, color: AppTheme.error),
                const SizedBox(width: 4),
                Text(
                  widget.errorText!,
                  style: GoogleFonts.inter(
                    color: AppTheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =========================================================
// SISTEMAS DE FONDO (Visualmente adaptados al Dark Mode)
// =========================================================

class _FieldMarkings extends StatelessWidget {
  final bool isDesktop;
  const _FieldMarkings({this.isDesktop = false});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FieldPainter(isDesktop: isDesktop),
      size: Size.infinite,
    );
  }
}

class _FieldPainter extends CustomPainter {
  final bool isDesktop;
  _FieldPainter({required this.isDesktop});
  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = isDesktop ? 16.0 : 12.0;
    final double fontSize = isDesktop ? 90.0 : 50.0;

    final linePaint = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final textSpanStyle = GoogleFonts.oswald(
      color: AppTheme.textPrimary.withValues(alpha: 0.15),
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

    double topPadding = size.height * 0.05;
    double bottomPadding = size.height * 0.05;
    double fieldHeight = size.height - (topPadding + bottomPadding);
    int totalYards = 50;
    int stepYards = 5;
    double pixelsPerYard = fieldHeight / totalYards;

    for (int y = 0; y <= totalYards; y += stepYards) {
      double currentY = topPadding + (y * pixelsPerYard);
      bool hasNumber = (y == 10 || y == 25 || y == 40);
      bool isEndZone = (y == 0 || y == 50);
      double baseLength = isDesktop ? 80.0 : 50.0;
      double markLength = hasNumber ? (baseLength / 2) : baseLength;

      if (isEndZone) {
        final thinLinePaint = Paint()
          ..color = AppTheme.textPrimary.withValues(alpha: 0.08)
          ..strokeWidth = strokeWidth / 3
          ..strokeCap = StrokeCap.butt;

        double extendedLength = markLength * 1.5;
        canvas.drawLine(
          Offset(size.width - extendedLength, currentY),
          Offset(size.width, currentY),
          thinLinePaint,
        );
        if (isDesktop) {
          canvas.drawLine(
            Offset(0, currentY),
            Offset(extendedLength, currentY),
            thinLinePaint,
          );
        }
      } else {
        canvas.drawLine(
          Offset(size.width - markLength, currentY),
          Offset(size.width, currentY),
          linePaint,
        );
        if (isDesktop) {
          canvas.drawLine(
            Offset(0, currentY),
            Offset(markLength, currentY),
            linePaint,
          );
        }
      }

      String? label;
      if (y == 10) label = "10";
      if (y == 25) label = "25";
      if (y == 40) label = "10";

      if (label != null) {
        final textSpan = TextSpan(text: label, style: textSpanStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        );
        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(
            size.width - markLength - textPainter.width - 15,
            currentY - (textPainter.height / 1.7),
          ),
        );
        if (isDesktop) {
          textPainter.paint(
            canvas,
            Offset(markLength + 15, currentY - (textPainter.height / 1.7)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum RouteType { go, inRoute, post }

class PlayRoute {
  final String id;
  final RouteType type;
  final Offset startOffset;
  final bool isLeft;
  final bool isUpwards;
  final double scale;
  final double speed;
  double progress;

  PlayRoute({
    required this.id,
    required this.type,
    required this.startOffset,
    required this.isLeft,
    required this.isUpwards,
    required this.scale,
    required this.speed,
    this.progress = 0.0,
  });
}

class _PlaybookBackground extends StatefulWidget {
  const _PlaybookBackground();
  @override
  State<_PlaybookBackground> createState() => _PlaybookBackgroundState();
}

class _PlaybookBackgroundState extends State<_PlaybookBackground> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<PlayRoute> _routes = [];
  final Random _rnd = Random();
  bool _nextSpawnFromTop = true;
  int _cooldownStart = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final int now = elapsed.inMilliseconds;
    setState(() {
      for (var r in _routes) {
        r.progress += (0.005 * r.speed);
      }
      _routes.removeWhere((r) => r.progress >= 1.5);
    });
    if (_routes.isEmpty) {
      if (_cooldownStart == 0) {
        _cooldownStart = now;
      } else {
        if (now - _cooldownStart > 1500) {
          _spawnGroupOfThree();
          _cooldownStart = 0;
        }
      }
    }
  }

  void _spawnGroupOfThree() {
    final size = MediaQuery.of(context).size;
    if (size.isEmpty) return;
    bool isDesktop = size.width > 900;
    bool fromTop = _nextSpawnFromTop;
    double startY = fromTop ? 0.0 : size.height;
    bool isUpwards = !fromTop;
    _nextSpawnFromTop = !_nextSpawnFromTop;
    double zoneWidth = size.width / 3;
    for (int i = 0; i < 3; i++) {
      double minX = (i * zoneWidth);
      double maxX = ((i + 1) * zoneWidth);
      double startX = minX + _rnd.nextDouble() * (maxX - minX);
      double baseScale = isDesktop ? 1.8 : 1.2;
      double scale = baseScale + (_rnd.nextDouble() * 1.3);
      bool isLeft = _rnd.nextBool();
      final type = RouteType.values[_rnd.nextInt(RouteType.values.length)];
      double speedFactor = 0.8 + (_rnd.nextDouble() * 0.4);
      _routes.add(
        PlayRoute(
          id: DateTime.now().toIso8601String() + i.toString(),
          type: type,
          startOffset: Offset(startX, startY),
          isLeft: isLeft,
          isUpwards: isUpwards,
          scale: scale,
          speed: speedFactor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePainter(routes: _routes),
      size: Size.infinite,
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<PlayRoute> routes;
  _RoutePainter({required this.routes});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.brandTeal.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppTheme.brandTeal.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (var route in routes) {
      double opacity = 0.35;
      if (route.progress < 0.2) {
        opacity = 0.35 * (route.progress / 0.2);
      } else if (route.progress > 1.0) {
        double fadeOut = 1.0 - ((route.progress - 1.0) / 0.5);
        opacity = 0.35 * fadeOut;
      }
      if (opacity <= 0) continue;

      paint.color = AppTheme.brandTeal.withOpacity(opacity);
      dotPaint.color = AppTheme.brandTeal.withOpacity(opacity);

      Path fullPath = Path();
      fullPath.moveTo(route.startOffset.dx, route.startOffset.dy);
      double dirX = route.isLeft ? -1.0 : 1.0;
      double dirY = route.isUpwards ? -1.0 : 1.0;
      double scale = route.scale;

      switch (route.type) {
        case RouteType.go:
          fullPath.lineTo(
            route.startOffset.dx,
            route.startOffset.dy + (200 * dirY * scale),
          );
          break;
        case RouteType.inRoute:
          fullPath.lineTo(
            route.startOffset.dx,
            route.startOffset.dy + (100 * dirY * scale),
          );
          fullPath.lineTo(
            route.startOffset.dx + (100 * dirX * scale),
            route.startOffset.dy + (100 * dirY * scale),
          );
          break;
        case RouteType.post:
          fullPath.lineTo(
            route.startOffset.dx,
            route.startOffset.dy + (80 * dirY * scale),
          );
          fullPath.lineTo(
            route.startOffset.dx + (60 * dirX * scale),
            route.startOffset.dy + (200 * dirY * scale),
          );
          break;
      }
      ui.PathMetrics pathMetrics = fullPath.computeMetrics();
      for (ui.PathMetric metric in pathMetrics) {
        double totalLength = metric.length * min(route.progress, 1.0);
        Path dashedPath = metric.extractPath(0.0, totalLength);
        _drawDashedPath(canvas, dashedPath, paint);
        if (totalLength > 5) {
          final ui.Tangent? tipTangent = metric.getTangentForOffset(totalLength);
          if (tipTangent != null) {
            canvas.drawCircle(
              tipTangent.position,
              10.0 * (scale * 0.5).clamp(0.5, 1.5),
              dotPaint,
            );
          }
        }
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    ui.PathMetrics metrics = path.computeMetrics();
    for (ui.PathMetric metric in metrics) {
      double dashWidth = 16.0;
      double dashSpace = 12.0;
      double distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => true;
}
