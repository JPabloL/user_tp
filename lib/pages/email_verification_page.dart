import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/join_team_link.dart';
import '../services/storage_service.dart';
import '../services/toast_service.dart';
import 'home_page.dart';
import 'join_team_page.dart';
import 'login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.api,
    required this.storage,
  });

  static const String route = '/email-verification';

  final ApiService api;
  final StorageService storage;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool isLoading = false;
  bool isResending = false;
  int resendCooldown = 0;
  Timer? cooldownTimer;

  @override
  void dispose() {
    cooldownTimer?.cancel();
    super.dispose();
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ToastService.show(message, isError: isError);
  }

  void _setLoading(bool value) {
    if (mounted) {
      setState(() => isLoading = value);
    }
  }

  void startCooldown() {
    setState(() {
      resendCooldown = 60;
    });
    cooldownTimer?.cancel();
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (resendCooldown > 0) {
          setState(() {
            resendCooldown--;
          });
        } else {
          timer.cancel();
        }
      }
    });
  }

  Future<void> checkVerificationStatus() async {
    _setLoading(true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setLoading(false);
        _goToLogin();
        return;
      }

      // Recarga el usuario para refrescar el estado del servidor
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // Carga el contexto para guardar sesión y redirecciona
        final res = await widget.api.getUserContext(refreshedUser.uid);
        _setLoading(false);

        if (res['status'] == 'ok' && res['user'] != null) {
          final dbUser = Map<String, dynamic>.from(res['user'] as Map);
          
          // Guardar en CouchDB de forma permanente que el correo ya fue validado
          if (dbUser['mail_verified'] != true) {
            dbUser['mail_verified'] = true;
            try {
              await widget.api.updateDoc(dbUser);
            } catch (_) {
              // Si falla por algún detalle de red local, permitimos continuar
            }
          }

          final roles = (res['roles'] as Map<String, dynamic>?) ?? <String, dynamic>{};
          final token = await refreshedUser.getIdToken();

          final sessionData = <String, dynamic>{
            'id': dbUser['_id'],
            'uid': refreshedUser.uid,
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

          _toast('¡Correo verificado con éxito!');
          await _goToNextAfterVerification();
        } else {
          if (!mounted) return;
          _toast('Sesión lista, pero hubo un detalle al sincronizar.', isError: true);
          await _goToNextAfterVerification();
        }
      } else {
        _setLoading(false);
        _toast(
          'El correo aún no ha sido verificado. Por favor haz clic en el enlace enviado.',
          isError: true,
        );
      }
    } catch (e) {
      _setLoading(false);
      _toast('Error al comprobar estado. Intenta nuevamente.', isError: true);
    }
  }

  Future<void> resendVerificationEmail() async {
    if (resendCooldown > 0) return;

    setState(() => isResending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        _toast('Se ha reenviado el enlace de verificación.');
        startCooldown();
      } else {
        _goToLogin();
      }
    } catch (_) {
      _toast('Error al enviar el enlace. Intenta más tarde.', isError: true);
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  Future<void> logoutAndChangeEmail() async {
    _setLoading(true);
    try {
      await FirebaseAuth.instance.signOut();
      await widget.storage.remove(AppConfig.sessionKey);
      _setLoading(false);
      _goToLogin();
    } catch (_) {
      _setLoading(false);
      _goToLogin();
    }
  }

  Future<void> _goToNextAfterVerification() async {
    final pendingJoin = await JoinTeamLink.readPending(widget.storage);
    if (!mounted) return;
    if (pendingJoin != null && pendingJoin.isNotEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        JoinTeamPage.route,
        (_) => false,
        arguments: {'token': pendingJoin},
      );
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      HomePage.route,
      (_) => false,
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginPage.route,
      (_) => false,
    );
  }

  Future<void> showChangeEmailDialog() async {
    final emailCtrl = TextEditingController(text: FirebaseAuth.instance.currentUser?.email);
    final formKey = GlobalKey<FormState>();
    bool dialogLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDFDFD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Cambiar Correo',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ingresa tu nueva dirección de correo. Enviaremos un nuevo enlace de verificación.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Nuevo Correo',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF1F3F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un correo';
                        }
                        final cleaned = value.replaceAll(RegExp(r'\s'), '').toLowerCase();
                        final emailRegex = RegExp(r'^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}$');
                        if (!emailRegex.hasMatch(cleaned)) {
                          return 'Ingresa un correo válido';
                        }
                        if (cleaned == FirebaseAuth.instance.currentUser?.email) {
                          return 'Debe ser diferente al actual';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setDialogState(() => dialogLoading = true);
                          final newEmail = emailCtrl.text.replaceAll(RegExp(r'\s'), '').toLowerCase();
                          
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              // 1. Cambiar en Firebase Auth
                              // ignore: deprecated_member_use
                              await user.updateEmail(newEmail);
                              
                              // 2. Enviar nueva verificación
                              await user.sendEmailVerification();
                              
                              // 3. Actualizar en CouchDB
                              final session = await widget.storage.getJson(AppConfig.sessionKey);
                              if (session != null && session['uid'] != null) {
                                final res = await widget.api.getUserContext(session['uid'].toString());
                                if (res['status'] == 'ok' && res['user'] != null) {
                                  final dbUser = Map<String, dynamic>.from(res['user'] as Map);
                                  dbUser['mail'] = newEmail;
                                  dbUser['mail_verified'] = false; // se resetea
                                  await widget.api.updateDoc(dbUser);
                                  
                                  // 4. Actualizar sesión local
                                  session['mail'] = newEmail;
                                  await widget.storage.setJson(AppConfig.sessionKey, session);
                                }
                              }
                              
                              if (context.mounted) {
                                Navigator.of(context).pop(); // Cerrar diálogo
                              }
                              _toast('Correo actualizado. Por favor verifica el nuevo enlace.');
                              startCooldown();
                            }
                          } on FirebaseAuthException catch (e) {
                            String errorMsg = 'Error al cambiar correo.';
                            if (e.code == 'email-already-in-use') {
                              errorMsg = 'El correo ya está en uso por otra cuenta.';
                            } else if (e.code == 'invalid-email') {
                              errorMsg = 'El formato del correo es inválido.';
                            } else if (e.code == 'requires-recent-login') {
                              errorMsg = 'Por seguridad, requiere volver a iniciar sesión.';
                            } else if (e.message != null) {
                              errorMsg = e.message!;
                            }
                            _toast(errorMsg, isError: true);
                          } catch (err) {
                            _toast('Error inesperado: $err', isError: true);
                          } finally {
                            setDialogState(() => dialogLoading = false);
                          }
                        },
                  child: dialogLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'tu correo';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          // Decoración estética de fondo coherente con el LoginPage
          const Positioned(
            top: -120,
            right: -80,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: Color(0x0A000000),
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
                color: const Color(0x05000000),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFD),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Encabezado con Icono en Insignia Premium
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFC8E6C9),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.mark_email_read_rounded,
                              color: Color(0xFF2E7D32),
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Verifica tu correo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Hemos enviado un enlace de confirmación para validar tu identidad y activar tu perfil seguro.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Caja destacada de correo electrónico
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alternate_email_rounded,
                                size: 18,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  userEmail,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Botón Principal: Verificar Estado
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isLoading ? null : checkVerificationStatus,
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Ya verifiqué mi correo',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Botón Secundario: Reenviar Enlace
                        OutlinedButton(
                          onPressed: (isLoading || isResending || resendCooldown > 0)
                              ? null
                              : resendVerificationEmail,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: resendCooldown > 0
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isResending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                  ),
                                )
                              : Text(
                                  resendCooldown > 0
                                      ? 'Reenviar en ${resendCooldown}s'
                                      : 'Reenviar enlace de confirmación',
                                  style: TextStyle(
                                    color: resendCooldown > 0
                                        ? Colors.grey
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        // Botón para cambiar el correo de esta cuenta
                        TextButton(
                          onPressed: isLoading ? null : showChangeEmailDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Corregir / Cambiar correo electrónico',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Enlace de escape: Cerrar sesión / cambiar de correo
                        TextButton(
                          onPressed: isLoading ? null : logoutAndChangeEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Registrar otro correo / Salir',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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
        ],
      ),
    );
  }
}
