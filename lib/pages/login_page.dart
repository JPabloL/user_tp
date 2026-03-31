import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../pages/home_page.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';

enum LoginView { enter, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.storage});

  static const String route = '/login';

  final ApiService api;
  final StorageService storage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginView view = LoginView.enter;
  final _nameCtrl = TextEditingController();
  final _mailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passCompareCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool passCheck = true;
  bool recover = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mailCtrl.dispose();
    _passCtrl.dispose();
    _passCompareCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!_cleanAndValidateEmail()) return;
    if (_passCtrl.text.isEmpty) {
      ToastService.show(context, 'Falta la contraseña', isError: true);
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
    } catch (_) {
      _setLoading(false);
      _toast('Error de conexión con el servidor', isError: true);
    }
  }

  Future<void> register() async {
    if (!_cleanAndValidateEmail()) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ToastService.show(context, 'El nombre es obligatorio', isError: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      ToastService.show(context, 'El teléfono es obligatorio', isError: true);
      return;
    }
    if (!passCheck) {
      ToastService.show(context, 'Las contraseñas no coinciden', isError: true);
      return;
    }
    if (_passCtrl.text.isEmpty) {
      ToastService.show(context, 'Falta la contraseña', isError: true);
      return;
    }

    _setLoading(true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _mailCtrl.text,
        password: _passCtrl.text,
      );

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
      final res = await widget.api.getUserContext(firebaseUser.uid);
      _setLoading(false);
      if (res['status'] == 'ok' && res['user'] != null) {
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
        await widget.storage.setJson(AppConfig.sessionKey, sessionData);
        if (!mounted) return;

        final firstName = (dbUser['name']?.toString() ?? 'Usuario').split(' ').first;
        _toast('Bienvenido $firstName');
        _goToNextByProfile(dbUser, roles);
      } else {
        _toast('Error al cargar perfil. Intenta de nuevo.', isError: true);
      }
    } catch (_) {
      _setLoading(false);
      _toast('Error de conexión con el servidor', isError: true);
    }
  }

  void _goToNextByProfile(
    Map<String, dynamic> dbUser,
    Map<String, dynamic> roles,
  ) {
    final rawStep = dbUser['verification_step']?.toString();
    final currentStep = int.tryParse(rawStep ?? '0') ?? 0;
    final isPlayer = roles['isPlayer'] == true;
    final isTutor = roles['isTutor'] == true;

    final playerIncomplete = isPlayer && currentStep < 3;
    final tutorIncomplete = isTutor && currentStep < 2;
    final newUser = (!isPlayer && !isTutor) || currentStep == 0;

    if (playerIncomplete || tutorIncomplete || newUser) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        HomePage.route,
        (_) => false,
      );
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        HomePage.route,
        (_) => false,
      );
    }
  }

  Future<void> sendRecovery() async {
    if (_mailCtrl.text.trim().isEmpty) return;
    if (!_cleanAndValidateEmail()) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _mailCtrl.text);
      if (!mounted) return;
      _toast('Correo enviado');
      setState(() => recover = false);
    } on FirebaseAuthException catch (e) {
      _toast(translateError(e.code), isError: true);
    }
  }

  void compareText() {
    setState(() {
      passCheck = _passCtrl.text == _passCompareCtrl.text;
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
      _toast('El correo es obligatorio', isError: true);
      return false;
    }

    final cleaned = _mailCtrl.text.replaceAll(RegExp(r'\s'), '').toLowerCase();
    _mailCtrl.text = cleaned;

    final emailRegex = RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$');
    if (!emailRegex.hasMatch(cleaned)) {
      _toast('El formato del correo es inválido', isError: true);
      return false;
    }
    return true;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(context, message, isError: isError);
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() => isLoading = value);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    IconData? icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.black, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = view == LoginView.enter ? 'Inicia sesión' : 'Crea tu cuenta';
    final subtitle = view == LoginView.enter
        ? 'Rendimiento, control y gestión en una sola cuenta.'
        : 'Crea tu cuenta para administrar tu perfil deportivo.';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -80,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: Color(0x1A000000),
            ),
          ),
          Positioned(
            top: -70,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                color: const Color(0x0F000000),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 30,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'TOCHITO PRO',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 2.2,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF70757D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF68707A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<LoginView>(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.black
                                  : Colors.white,
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(value: LoginView.enter, label: Text('Entrar')),
                            ButtonSegment(value: LoginView.register, label: Text('Registrar')),
                          ],
                          selected: {view},
                          onSelectionChanged: (value) => setState(() => view = value.first),
                        ),
                        const SizedBox(height: 18),
                        if (view == LoginView.register) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: _fieldDecoration(
                              label: 'Nombre completo',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDecoration(
                              label: 'Teléfono',
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _mailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _fieldDecoration(
                            label: 'Correo',
                            icon: Icons.mail_outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          onChanged: (_) => compareText(),
                          decoration: _fieldDecoration(
                            label: 'Contraseña',
                            icon: Icons.lock_outline,
                          ),
                        ),
                        if (view == LoginView.register) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passCompareCtrl,
                            obscureText: true,
                            onChanged: (_) => compareText(),
                            decoration: _fieldDecoration(
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_person_outlined,
                              errorText: passCheck ? null : 'No coincide',
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () => view == LoginView.enter ? login() : register(),
                            child: Text(
                              view == LoginView.enter ? 'Entrar' : 'Crear cuenta',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() => recover = !recover),
                          child: const Text(
                            'Recuperar contraseña',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (recover)
                          OutlinedButton(
                            onPressed: isLoading ? null : sendRecovery,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Enviar correo de recuperación'),
                          ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 16, color: Colors.black54),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Acceso seguro con autenticación por correo.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF5E6670)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isLoading)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
