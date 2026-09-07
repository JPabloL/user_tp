import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/primary_button.dart';
import '../widgets/modern_loading_overlay.dart';
import '../services/api_service.dart';
import '../services/curp_service.dart';
import '../services/toast_service.dart';
import '../utils/navigation_helpers.dart';
import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({
    super.key,
    required this.api,
    required this.curpService,
    required this.parentId,
    this.prefillCurp,
    this.initialChild,
    this.parentName,
    this.parentCurp,
    this.parentApPa,
    this.parentApMa,
    this.isSelfRegister = false,
  });

  static const String route = '/jugador-nuevo';

  final ApiService api;
  final CurpService curpService;
  final String parentId;
  final String? prefillCurp;
  final Map<String, dynamic>? initialChild;
  final String? parentName;
  final String? parentCurp;
  final String? parentApPa;
  final String? parentApMa;
  final bool isSelfRegister;

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  int step = 1;
  bool termsAccepted = false;
  bool isProcessingCurp = false;
  bool isSubmitting = false;
  bool isClaimMode = false;
  bool lockPersonalFields = false;
  bool isIdentityVerified = false;
  bool curpValidated = false;
  List<String> selectedPositions = [];
  final availablePositions = ['QB', 'WR', 'RB', 'C', 'DB', 'LB', 'R'];
  int ocrAttempts = 0;
  String existingTutorName = '';
  String existingTutorEmail = '';
  String? existingTutorId;
  bool isUploadingProfile = false;
  bool isProfileUploaded = false;
  bool isUploadingDoc = false;
  bool isDocUploaded = false;
  bool isManualReview = false;
  String docType = 'ine';
  String? createdPlayerId;
  String? existingPhotoUrl;
  XFile? profilePhoto;
  XFile? docPhoto;
  List<int>? lastDocBytes;
  Map<String, dynamic>? childDataForClaim;
  String? recoveryMode;
  String? accountType;

  final curpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final aliasCtrl = TextEditingController();
  final apPaCtrl = TextEditingController();
  final apMaCtrl = TextEditingController();
  final bdCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final numberCtrl = TextEditingController();
  final positionsCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  final legacyEmailCtrl = TextEditingController();
  final legacyPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hasInitialChild = widget.initialChild != null;
    if (hasInitialChild) {
      final child = widget.initialChild!;
      createdPlayerId = child['_id']?.toString() ?? child['playerId']?.toString() ?? child['id']?.toString();
      isIdentityVerified = (child['identity_status']?.toString() == 'verified');
      isManualReview = (child['identity_status']?.toString() == 'manual_review');
      
      final String curp = (child['curp']?.toString() ?? '').toUpperCase();
      curpCtrl.text = curp;
      _fillFormWithData(child);
      final rawPhoto = child['photo']?.toString();
      existingPhotoUrl = (rawPhoto == 'null' || rawPhoto == null || rawPhoto.trim().isEmpty) ? null : rawPhoto;

      if (isManualReview) {
        lockPersonalFields = true;
        curpValidated = true;
        step = 2;
      } else if ((curp.isNotEmpty && curp.length == 18) || createdPlayerId != null) {
        lockPersonalFields = true;
        curpValidated = true;
        // Removed auto skip to step 2 so user can review basic info first
      } else {
        lockPersonalFields = false;
        curpValidated = false;
        step = 1;
      }
    }
    if (widget.isSelfRegister && widget.parentCurp != null) {
      curpCtrl.text = widget.parentCurp!.toUpperCase();
      lockPersonalFields = true;
      curpValidated = true;
      nameCtrl.text = _toTitleCase(widget.parentName ?? '');
      apPaCtrl.text = _toTitleCase(widget.parentApPa ?? '');
      apMaCtrl.text = _toTitleCase(widget.parentApMa ?? '');
      Future.delayed(const Duration(milliseconds: 400), validateCurpLogic);
    } else if (!hasInitialChild && (widget.prefillCurp ?? '').isNotEmpty) {
      curpCtrl.text = widget.prefillCurp!.toUpperCase();
      Future.delayed(const Duration(milliseconds: 400), validateCurpLogic);
    }
  }

  @override
  void dispose() {
    curpCtrl.dispose();
    nameCtrl.dispose();
    aliasCtrl.dispose();
    apPaCtrl.dispose();
    apMaCtrl.dispose();
    bdCtrl.dispose();
    genderCtrl.dispose();
    numberCtrl.dispose();
    positionsCtrl.dispose();
    pinCtrl.dispose();
    legacyEmailCtrl.dispose();
    legacyPasswordCtrl.dispose();
    super.dispose();
  }

  String _playerAge = '';
  String _playerCreatedAt = '';

  Future<void> validateCurpLogic() async {
    final curpInput = curpCtrl.text.trim().toUpperCase();
    if (curpInput.length != 18) {
      _toast('La CURP debe tener 18 caracteres', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      isProcessingCurp = true;
      isClaimMode = false;
      childDataForClaim = null;
      pinCtrl.clear();
      legacyEmailCtrl.clear();
      legacyPasswordCtrl.clear();
    });
    try {
      final res = await widget.curpService.getDetails(curpInput);
      setState(() => curpValidated = true);
      isClaimMode = false;
      final source = res['source']?.toString();
      if (source == 'player_exists') {
        final data = (res['data'] as Map<String, dynamic>?) ?? {};
        final currentTutorId = data['tutorId']?.toString() ?? data['tutor']?['id']?.toString() ?? data['tutor']?['_id']?.toString();
        createdPlayerId = res['playerId']?.toString();
        recoveryMode = res['recoveryMode']?.toString();
        accountType = res['accountType']?.toString();
        _fillFormWithData(data);
        lockPersonalFields = true;
        isIdentityVerified = (data['identity_status']?.toString() == 'verified');
        final rawDataPhoto = data['photo']?.toString();
        existingPhotoUrl = (rawDataPhoto == 'null' || rawDataPhoto == null || rawDataPhoto.trim().isEmpty) ? null : rawDataPhoto;
        
        if (currentTutorId == widget.parentId) {
          if (isIdentityVerified) {
            _toast('Perfil ya validado. Solo actualiza jersey y posiciones.');
          } else {
            _toast('Registro previo recuperado. Continua la validacion.');
          }
        } else {
          childDataForClaim = data;
          existingTutorName = res['tutorName']?.toString() ?? 'Otro tutor';
          
          String emailRaw = data['contactEmail']?.toString() ?? data['email']?.toString() ?? data['tutor']?['mail']?.toString() ?? data['tutor']?['email']?.toString() ?? '';
          if (emailRaw.isEmpty) {
            existingTutorEmail = 'Sin correo registrado';
          } else if (emailRaw.contains('@')) {
            final parts = emailRaw.split('@');
            final name = parts[0];
            final domain = parts[1];
            if (name.length > 3) {
              existingTutorEmail = '${name.substring(0, name.length - 3)}***@$domain';
            } else {
              existingTutorEmail = '${name.replaceAll(RegExp(r'.'), '*')}@$domain';
            }
          } else {
            existingTutorEmail = emailRaw;
          }
          
          existingTutorId = currentTutorId;
          isClaimMode = true;
          _toast('Jugador registrado por: $existingTutorName', isError: true);
        }
      } else {
        final data = (res['data'] as Map<String, dynamic>?) ?? res;
        _fillFormWithData(data);
        lockPersonalFields = true;
        isIdentityVerified = (data['identity_status']?.toString() == 'verified');
        _toast('Datos cargados correctamente');
      }
    } catch (e) {
      print('ERROR EN validateCurpLogic: $e');
      _toast('Error consultando CURP: $e', isError: true);
    }
    if (mounted) setState(() => isProcessingCurp = false);
  }

  void _fillFormWithData(Map<String, dynamic> data) {
    nameCtrl.text = _toTitleCase(
      data['Nombres']?.toString() ?? data['nombres']?.toString() ?? data['name']?.toString() ?? '',
    );
    apPaCtrl.text = _toTitleCase(
      data['ApellidoPaterno']?.toString() ??
          data['apellido1']?.toString() ??
          data['apellidoPa']?.toString() ??
          '',
    );
    apMaCtrl.text = _toTitleCase(
      data['ApellidoMaterno']?.toString() ??
          data['apellido2']?.toString() ??
          data['apellidoMa']?.toString() ??
          '',
    );
    bdCtrl.text = data['FechaNacimiento']?.toString() ??
        data['fechaNacimiento']?.toString() ??
        data['bd']?.toString() ??
        '';
    genderCtrl.text =
        data['Sexo']?.toString() ?? data['sexo']?.toString() ?? data['gender']?.toString() ?? '';
    numberCtrl.text = data['number']?.toString() ?? '';
    aliasCtrl.text = data['alias']?.toString() ?? '';
    final positions = data['positions'];
    if (positions is List) {
      selectedPositions = positions.map((e) => e.toString()).toList();
      positionsCtrl.text = selectedPositions.join(',');
    } else {
      positionsCtrl.text = positions?.toString() ?? '';
    }

    if (data['age'] != null) {
      _playerAge = data['age'].toString();
    } else if (bdCtrl.text.isNotEmpty) {
      try {
        final parts = bdCtrl.text.split('-');
        if (parts.length == 3) {
          final bd = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final now = DateTime.now();
          int age = now.year - bd.year;
          if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
            age--;
          }
          _playerAge = age.toString();
        }
      } catch (_) {}
    }

    _playerCreatedAt = data['sd']?.toString() ?? data['created_at']?.toString() ?? data['createdAt']?.toString() ?? data['fechaAlta']?.toString() ?? 'Sin fecha';
    if (_playerCreatedAt.contains('T')) {
      _playerCreatedAt = _playerCreatedAt.split('T')[0];
    }
  }

  String _normalizeString(String text) {
    return text.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  bool get _canContinueStep1 {
    if (!curpValidated || isClaimMode) return false;
    return numberCtrl.text.trim().isNotEmpty && selectedPositions.isNotEmpty;
  }

  bool get _needsJerseyNumber =>
      curpValidated && !isClaimMode && numberCtrl.text.trim().isEmpty;

  bool get _needsPositionSelection =>
      curpValidated && !isClaimMode && selectedPositions.isEmpty;

  String? get _step1ContinueHint {
    if (!curpValidated || isClaimMode || isIdentityVerified) return null;
    if (_needsJerseyNumber && _needsPositionSelection) {
      return 'Ingresa el número de jersey y selecciona al menos una posición para continuar.';
    }
    if (_needsJerseyNumber) {
      return 'Ingresa el número de jersey para continuar.';
    }
    if (_needsPositionSelection) {
      return 'Selecciona al menos una posición para continuar con la validación.';
    }
    return null;
  }

  bool get _hasOfficialPhoto =>
      isProfileUploaded || (existingPhotoUrl ?? '').isNotEmpty;

  bool get _canFinishStep2 =>
      _hasOfficialPhoto && isDocUploaded && termsAccepted;

  bool get _needsIdentityDocument =>
      step == 2 && _hasOfficialPhoto && !isDocUploaded;

  String? get _step2FinishHint {
    if (step != 2) return null;
    if (!_hasOfficialPhoto) {
      return 'Captura primero la foto oficial del jugador.';
    }
    if (!isDocUploaded && !termsAccepted) {
      return 'Sube el documento de identificación y acepta el consentimiento legal para finalizar.';
    }
    if (!isDocUploaded) {
      return 'Falta subir el documento de identificación. Toca "Subir documento" y captura una foto clara.';
    }
    if (!termsAccepted) {
      return 'Acepta el consentimiento legal para finalizar la validación.';
    }
    return null;
  }

  Future<void> submitStep1() async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Faltan datos personales', isError: true);
    if (apPaCtrl.text.trim().isEmpty) return _toast('Ingresa el apellido paterno', isError: true);
    if (apMaCtrl.text.trim().isEmpty) return _toast('Ingresa el apellido materno', isError: true);
    if (numberCtrl.text.trim().isEmpty) return _toast('Ingresa el número de jersey', isError: true);
    if (selectedPositions.isEmpty) return _toast('Selecciona una posición', isError: true);
    positionsCtrl.text = selectedPositions.join(',');

    // Strict Last Name / Relationship Validation removed by user request

    // Si ya existe y ya está validado, no forzamos revalidación de identidad.
    if (createdPlayerId != null && isIdentityVerified) {
      _toast('Este perfil ya está validado. No requiere subir evidencia nuevamente.');
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Si ya existe (aunque no esté verificado), solo pasamos a evidencia.
    if (createdPlayerId != null) {
      setState(() => step = 2);
      return;
    }

    if (isClaimMode && createdPlayerId != null) {
      setState(() => step = 2);
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final res = await widget.api.createChildProfile({
        'parentId': widget.parentId,
        'curp': curpCtrl.text.trim().toUpperCase(),
        'name': nameCtrl.text.trim(),
        'alias': aliasCtrl.text.trim(),
        'apellidoPa': apPaCtrl.text.trim(),
        'apellidoMa': apMaCtrl.text.trim(),
        'bd': bdCtrl.text.trim(),
        'gender': genderCtrl.text.trim(),
        'number': numberCtrl.text.trim(),
        'positions': positionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      });
      if (res['status'] == 'ok') {
        createdPlayerId = res['playerId']?.toString();
        setState(() => step = 2);
        _toast('Perfil creado. Ahora valida su identidad.');
      } else {
        _toast((res['message'] ?? 'No se pudo crear').toString(), isError: true);
      }
    } catch (e) {
      print('ERROR EN submitStep1: $e');
      _toast(_friendlyError(e), isError: true);
    }
    if (mounted) setState(() => isSubmitting = false);
  }

  Future<void> takePhoto(String type) async {
    final picker = ImagePicker();

    Future<void> pick(ImageSource source) async {
      try {
        final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200, maxHeight: 1200);
        if (file == null) return;
        if (createdPlayerId == null) {
           _toast('No se encontró ID de jugador', isError: true);
           return;
        }

        if (type == 'profile') {
          setState(() {
            profilePhoto = file;
            isUploadingProfile = true;
          });
          await widget.api.uploadChildRosterPhoto(
            playerId: createdPlayerId!,
            bytes: await file.readAsBytes(),
          );
          setState(() {
            isUploadingProfile = false;
            isProfileUploaded = true;
          });
          _toast('Foto de perfil subida correctamente');
        } else {
          final docBytes = await file.readAsBytes();
          setState(() {
            docPhoto = file;
            lastDocBytes = docBytes;
            isUploadingDoc = true;
          });
          final resValidation = await widget.api.validateChildIdentity(
            playerId: createdPlayerId!,
            docBytes: docBytes,
            docType: docType,
          );
          if (resValidation['status'] == 'ok') {
            setState(() {
              isUploadingDoc = false;
              isDocUploaded = true;
            });
            _toast('Documento validado correctamente');
          } else {
            ocrAttempts++;
            setState(() {
              isUploadingDoc = false;
            });
            if (ocrAttempts >= 2) {
              await _showManualReviewOption();
              return;
            }
            setState(() {
              docPhoto = null;
              lastDocBytes = null;
            });
            _showAlert('Validación fallida', (resValidation['message'] ?? 'Intenta de nuevo').toString());
          }
        }
      } catch (e) {
        setState(() {
          if (type == 'profile') isUploadingProfile = false;
          else isUploadingDoc = false;
        });
        _toast('Error: $e', isError: true);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(context);
                pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submitStep2() async {
    if (createdPlayerId == null) return _toast('No se encontró ID de jugador', isError: true);
    final hasRoster = isProfileUploaded || (existingPhotoUrl ?? '').isNotEmpty;
    if (!hasRoster) return _toast('Falta la foto de perfil (Roster)', isError: true);
    if (!isDocUploaded) return _toast('Falta la foto del documento o validación', isError: true);
    if (!termsAccepted) return _toast('Debes aceptar consentimiento legal', isError: true);

    await _showAlert('Registro exitoso', 'La identidad del jugador fue validada correctamente.');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
  }

  Future<void> _showManualReviewOption() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Problemas técnicos'),
        content: const Text('Deseas enviarlo a revisión manual?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Intentar otra vez')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await executeManualUpload();
            },
            child: Text('Enviar a revisión'),
          ),
        ],
      ),
    );
  }

  Future<void> executeManualUpload() async {
    if (createdPlayerId == null) return;
    final bytes = lastDocBytes ??
        (docPhoto != null ? await docPhoto!.readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) {
      _toast('Falta la foto del documento para enviarla a revisión', isError: true);
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final res = await widget.api.requestManualReview(
        playerId: createdPlayerId!,
        docBytes: bytes,
        docType: docType,
      );
      if (res['status'] != 'ok') {
        _toast(
          (res['message'] ?? 'No se pudo enviar a revisión').toString(),
          isError: true,
        );
        return;
      }
      setState(() => isManualReview = true);
      _toast('Solicitud enviada. Perfil en revisión.');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _showAlert(String title, String msg) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
      ),
    );
  }

  Future<void> _fetchAndShowTutorEmail() async {
    if (existingTutorId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF3BD0AE))),
    );
    try {
      final res = await widget.api.getTutorById(existingTutorId!);
      if (mounted) Navigator.of(context).pop(); // close loading
      
      if (res['status'] == 'ok' && res['tutor'] != null) {
        String email = res['tutor']['mail']?.toString() ?? '';
        if (email.isEmpty) {
          email = 'Sin correo registrado';
        } else if (email.contains('@')) {
          final parts = email.split('@');
          final name = parts[0];
          final domain = parts[1];
          if (name.length > 3) {
            final visibleName = name.substring(0, name.length - 3);
            email = '$visibleName***@$domain';
          } else {
            email = '${name.replaceAll(RegExp(r'.'), '*')}@$domain';
          }
        }
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E2738),
              title: const Text('Contacto del Tutor', style: TextStyle(color: Colors.white)),
              content: Text(
                'Tutor: $existingTutorName\nCorreo: $email',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CERRAR', style: TextStyle(color: Color(0xFF3BD0AE))),
                ),
              ],
            ),
          );
        }
      } else {
        _toast('No se pudo obtener el correo del tutor', isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      _toast('Error de conexión', isError: true);
    }
  }

  Future<void> requestLegacyPassword() async {
    if (createdPlayerId == null) return _toast('No se pudo identificar al jugador', isError: true);

    setState(() => isSubmitting = true);
    try {
      final res = await widget.api.sendMailRecoverByPlayerId(
        playerId: createdPlayerId!,
      );
      
      if (res['status'] == 'firebase_required') {
        _toast('Esta cuenta utiliza un acceso moderno, cambiaremos tu contraseña mediante Firebase en el próximo paso.', isError: true);
        return;
      }
      
      if (res['status'] == 'error' || res['status'] == 'not_found' || res['ok'] == false) {
        throw Exception(res['message'] ?? 'Error al enviar la contraseña');
      }
      _toast('¡Contraseña enviada a tu correo exitosamente!');
    } catch (e) {
      _toast('Error: ${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> requestSupportTicket() async {
    if (createdPlayerId == null) return _toast('No se pudo identificar al jugador', isError: true);

    setState(() => isSubmitting = true);
    try {
      final payload = {
        "origin": "user",
        "requesterId": widget.parentId,
        "importance": "media",
        "category": "account",
        "issueType": "player_transfer",
        "subject": "Solicitud de transferencia de jugador",
        "description": "Solicito transferir el perfil del jugador a mi cuenta actual.",
        "userMessage": "Solicito transferir el perfil del jugador a mi cuenta actual.",
        "source": {
          "module": "account",
          "feature": "player_migration",
          "function": "requestPlayerTransfer",
          "screen": "PlayerMigrationPage",
          "action": "create_transfer_ticket"
        },
        "relatedEntities": {
          "requestingUserId": widget.parentId,
          "targetPlayerId": createdPlayerId
        },
        "metadata": {
          "requestType": "transfer_player_to_user"
        },
        "channel": "in_app",
        "tags": [
          "player-transfer",
          "account-migration"
        ]
      };

      print('=== ENVIANDO TICKET DE SOPORTE ===');
      print(payload);
      print('==================================');

      final res = await widget.api.createSupportTicket(
        ticketData: payload,
      );
      
      if (res['status'] == 'active_ticket_exists') {
        _toast('Ya tienes un ticket en progreso para esta solicitud.', isError: true);
        return;
      }
      
      if (res['status'] == 'error' || res['ok'] == false) {
        throw Exception(res['message'] ?? 'Error al crear el ticket');
      }
      _toast('¡Ticket de soporte creado exitosamente!');
    } catch (e) {
      _toast('Error: ${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> submitMigrationRequest() async {
    final email = legacyEmailCtrl.text.trim();
    final pass = legacyPasswordCtrl.text.trim();

    if (email.isEmpty) return _toast('Ingresa tu correo anterior', isError: true);
    if (pass.isEmpty) return _toast('Ingresa tu contraseña anterior', isError: true);
    if (createdPlayerId == null) return _toast('No se pudo identificar al jugador', isError: true);

    setState(() => isSubmitting = true);
    try {
      final res = await widget.api.linkPlayerToUser(
        playerId: createdPlayerId!,
        userId: widget.parentId,
        email: email,
        password: pass,
        userData: {
          'name': widget.parentName,
          'curp': widget.parentCurp,
          'apellidoPa': widget.parentApPa,
          'apellidoMa': widget.parentApMa,
        },
      );
      if (res['status'] == 'error' || res['ok'] == false) {
        throw Exception(res['message'] ?? 'Error al migrar la cuenta');
      }
      _toast('¡Migración exitosa! El perfil ya está en tu cuenta.');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Error al migrar: ${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> submitCoTutorRequest() async {
    final enteredPin = pinCtrl.text.trim().toUpperCase();
    if (enteredPin.length != 6) {
      return _toast('El PIN debe tener 6 caracteres', isError: true);
    }

    if (createdPlayerId == null) {
      return _toast('No se pudo identificar al jugador', isError: true);
    }

    setState(() => isSubmitting = true);
    try {
      final res = await widget.api.sendCoTutorshipRequest(
        uid: widget.parentId,
        curp: curpCtrl.text.trim().toUpperCase(),
        nipVinculacion: enteredPin,
      );

      if (res['status'] == 'error' || res['ok'] == false) {
        throw Exception(res['message'] ?? 'Error al enviar la solicitud');
      }

      _toast('¡Solicitud de co-tutoría enviada con éxito! Esperando aprobación del tutor primario.');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _toast('Error al enviar la solicitud: ${_friendlyError(e)}', isError: true);
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  String _toTitleCase(String str) {
    if (str.isEmpty) return '';
    return str
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _toast(String msg, {bool isError = false}) {
    ToastService.show(msg, isError: isError);
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }

  InputDecoration _fieldStyle(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.publicSans(color: Colors.white54, fontSize: 13),
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: const Color(0xFF3BD0AE)),
      filled: true,
      fillColor: const Color(0xFF161F2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: const BorderSide(color: Color(0xFF3BD0AE), width: 1.5),
      ),
    );
  }

  Widget _stepPill(int index, String text) {
    final active = step == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3BD0AE) : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFF3BD0AE) : Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.publicSans(
          color: active ? const Color(0xFF0F1722) : Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: const Color(0xFF0F1722),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 22),
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3BD0AE).withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: Color(0xFF3BD0AE), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'TOCHITO PRO',
                      style: GoogleFonts.oswald(
                        fontSize: 14,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => popOrGoHome(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'GESTIÓN DE JUGADOR',
                style: GoogleFonts.oswald(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step == 1
                    ? (curpValidated && !isClaimMode && !isIdentityVerified
                        ? 'Completa jersey y posición para continuar con la validación.'
                        : 'Captura datos y verifica CURP.')
                    : (isManualReview
                        ? 'Este perfil está en revisión manual de identidad.'
                        : (_hasOfficialPhoto && !isDocUploaded
                        ? 'La foto oficial ya está lista. Ahora sube el documento de identificación.'
                        : 'Sube evidencia para validar identidad.')),
                style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _stepPill(1, 'Paso 1: Datos'),
                  const SizedBox(width: 8),
                  if (!isIdentityVerified) _stepPill(2, 'Paso 2: Evidencia'),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: step == 1
                    ? Container(
                        key: const ValueKey('step-1'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2738),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!curpValidated)
                              TextField(
                                style: GoogleFonts.publicSans(color: Colors.white),
                                controller: curpCtrl,
                                readOnly: lockPersonalFields || curpValidated,
                                textCapitalization: TextCapitalization.characters,
                                decoration: _fieldStyle('CURP (18)', icon: Icons.badge_outlined),
                                onChanged: (_) {
                                  if (curpCtrl.text.length == 18) {
                                    validateCurpLogic();
                                  } else {
                                    setState(() {});
                                  }
                                },
                              ),
                            if (!curpValidated) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3BD0AE),
                                    foregroundColor: const Color(0xFF0F1722),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  onPressed: (isProcessingCurp || curpCtrl.text.trim().length != 18) ? null : validateCurpLogic,
                                  child: isProcessingCurp
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F1722), strokeWidth: 2))
                                      : const Text('Continuar'),
                                ),
                              ),
                            ],
                            if (curpValidated) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1722),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, color: Color(0xFF3BD0AE), size: 20),
                                        const SizedBox(width: 8),
                                        Text('DATOS DEL JUGADOR', style: GoogleFonts.oswald(color: Colors.white54, fontSize: 14, letterSpacing: 1.2)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text('${nameCtrl.text} ${apPaCtrl.text} ${apMaCtrl.text}', style: GoogleFonts.publicSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    if (curpCtrl.text.isNotEmpty)
                                      Text('CURP: ${curpCtrl.text}', style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 14)),
                                    Text('Nacimiento: ${bdCtrl.text} ($_playerAge años)', style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 14)),
                                    Text('Género: ${genderCtrl.text}', style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 14)),
                                    if (aliasCtrl.text.isNotEmpty)
                                      Text('Alias: ${aliasCtrl.text}', style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 14)),
                                    Text('Fecha de alta: $_playerCreatedAt', style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                            if (isClaimMode) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x20CF1322),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCF1322).withOpacity(0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFCF1322), size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Jugador ya registrado',
                                            style: GoogleFonts.publicSans(
                                              color: const Color(0xFFFF4D4F),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.publicSans(
                                            color: const Color(0xFFFF7875),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Este jugador ya está registrado bajo el usuario: '),
                                            TextSpan(
                                              text: '$existingTutorName con el correo: $existingTutorEmail',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                            const TextSpan(text: '.\n\n'),
                                            const TextSpan(
                                              text: 'Si el correo mostrado es tuyo, cierra esta sesión e ingresa con el correo correcto.',
                                              style: TextStyle(fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () async {
                                            await FirebaseAuth.instance.signOut();
                                            if (mounted) {
                                              Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.route, (_) => false);
                                            }
                                          },
                                          icon: const Icon(Icons.logout, size: 16),
                                          label: const Text('Cerrar sesión'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white70,
                                            textStyle: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Bloque de Migración (Accordion)
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161F2E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ExpansionTile(
                                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF3BD0AE), size: 20),
                                    title: Text(
                                      'Migrar a esta cuenta',
                                      style: GoogleFonts.publicSans(
                                        color: const Color(0xFF3BD0AE),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                    children: [
                                      Text(
                                        '¿Esa era tu cuenta anterior? Ingresa el correo que aparece asignado a la cuenta y la contraseña correspondiente para transferir este jugador a tu cuenta actual automáticamente.',
                                        style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 12.5),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: legacyEmailCtrl,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: _fieldStyle('Correo anterior', icon: Icons.email_outlined),
                                        style: GoogleFonts.publicSans(color: Colors.white),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: legacyPasswordCtrl,
                                        obscureText: true,
                                        decoration: _fieldStyle('Contraseña', icon: Icons.lock_outline),
                                        style: GoogleFonts.publicSans(color: Colors.white),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3BD0AE),
                                            foregroundColor: const Color(0xFF0F1722),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                          onPressed: isSubmitting ? null : submitMigrationRequest,
                                          child: isSubmitting
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F1722), strokeWidth: 2))
                                              : const Text('Transferir Jugador'),
                                        ),
                                      ),
                                      if (recoveryMode == 'legacy') ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.center,
                                          child: TextButton(
                                            onPressed: isSubmitting ? null : requestLegacyPassword,
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white70,
                                              textStyle: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text('¿Olvidaste tu contraseña? Enviarla a mi correo'),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.center,
                                        child: TextButton(
                                          onPressed: isSubmitting ? null : requestSupportTicket,
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFFFF7875),
                                            textStyle: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
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
                              ),
                              const SizedBox(height: 16),
                              // Bloque de Co-Tutoría (Accordion)
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161F2E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ExpansionTile(
                                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    leading: const Icon(Icons.group_add_outlined, color: Color(0xFF3BD0AE), size: 20),
                                    title: Text(
                                      'Solicitar Co-Tutoría',
                                      style: GoogleFonts.publicSans(
                                        color: const Color(0xFF3BD0AE),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                    children: [
                                      Text(
                                        'Para vincularte como Co-Tutor de este perfil y poder administrarlo conjuntamente, ingresa el PIN de Vinculación de 6 caracteres que el tutor primario tiene visible en su app.',
                                        style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 12.5),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: pinCtrl,
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 6,
                                        decoration: _fieldStyle(
                                          'PIN de Vinculación (6 caracteres)',
                                          icon: Icons.vpn_key_outlined,
                                        ).copyWith(
                                          counterText: '',
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 4.0,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3BD0AE),
                                            foregroundColor: const Color(0xFF0F1722),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                          onPressed: isSubmitting ? null : submitCoTutorRequest,
                                          child: isSubmitting
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F1722), strokeWidth: 2))
                                              : const Text('Enviar solicitud de vinculación'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // ── Modo Reclamo eliminado ────
                            if (curpValidated && lockPersonalFields && !isClaimMode)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161F2E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Text(
                                    'Datos personales bloqueados por CURP validada. Para continuar con la validación de identidad, completa el número de jersey y selecciona al menos una posición.',
                                    style: GoogleFonts.publicSans(
                                      color: Colors.white54,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),

                              if (curpValidated && !isClaimMode) ...[
                                const SizedBox(height: 16),
                                Text('DATOS DEPORTIVOS', style: GoogleFonts.oswald(color: Colors.white54, fontSize: 14, letterSpacing: 1.2)),
                                const SizedBox(height: 12),
                                TextField(
                                  style: GoogleFonts.publicSans(color: Colors.white),
                                  controller: numberCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: _fieldStyle('Número de Jersey', icon: Icons.confirmation_number_outlined),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      'POSICIONES',
                                      style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '* obligatorio',
                                      style: GoogleFonts.publicSans(
                                        color: const Color(0xFFFFD600),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_needsPositionSelection)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD600).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFD600).withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.touch_app_rounded,
                                          color: Color(0xFFFFD600),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Toca una o más posiciones del jugador. Sin esto no podrás continuar a la validación de identidad.',
                                            style: GoogleFonts.publicSans(
                                              color: const Color(0xFFFFE066),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _needsPositionSelection
                                          ? const Color(0xFFFFD600).withValues(alpha: 0.55)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: availablePositions.map((pos) {
                                      final isSelected = selectedPositions.contains(pos);
                                      return FilterChip(
                                        label: Text(pos, style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
                                        selected: isSelected,
                                        onSelected: (bool selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedPositions.add(pos);
                                            } else {
                                              selectedPositions.remove(pos);
                                            }
                                          });
                                        },
                                        selectedColor: const Color(0xFF3BD0AE),
                                        checkmarkColor: const Color(0xFF0F1722),
                                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF0F1722) : Colors.white),
                                        backgroundColor: const Color(0xFF161F2E),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: isSelected
                                                ? const Color(0xFF3BD0AE)
                                                : (_needsPositionSelection
                                                    ? const Color(0xFFFFD600).withValues(alpha: 0.35)
                                                    : Colors.white.withValues(alpha: 0.1)),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            if (curpValidated && !isClaimMode) ...[
                              if (_step1ContinueHint != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _step1ContinueHint!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.publicSans(
                                      color: const Color(0xFFFFD600),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3BD0AE),
                                    foregroundColor: const Color(0xFF0F1722),
                                    disabledBackgroundColor: Colors.white12,
                                    disabledForegroundColor: Colors.white38,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.publicSans(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                onPressed: isSubmitting || isProcessingCurp || (!isIdentityVerified && !_canContinueStep1)
                                    ? null
                                    : submitStep1,
                                child: Text(
                                  isIdentityVerified
                                      ? 'Guardar y volver'
                                      : _canContinueStep1
                                          ? 'Continuar a validación'
                                          : 'Completa jersey y posición',
                                ),
                              ),
                            ),
                            ],
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('step-2'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2738),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isManualReview) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD600).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'EN REVISIÓN MANUAL',
                                      style: GoogleFonts.publicSans(
                                        color: const Color(0xFFFFD600),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'El documento ya fue enviado. Un administrador lo atenderá y el perfil se actualizará cuando la identidad quede validada. No es necesario volver a subir documentos.',
                                      style: GoogleFonts.publicSans(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFFD600),
                                          side: const BorderSide(color: Color(0xFFFFD600)),
                                        ),
                                        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                                          HomePage.route,
                                          (_) => false,
                                        ),
                                        child: const Text('Volver a jugadores'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!isManualReview) ...[
                            if ((existingPhotoUrl ?? '').isEmpty && !isProfileUploaded) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF3BD0AE), side: BorderSide(color: const Color(0xFF3BD0AE).withOpacity(0.5))),
                                onPressed: isUploadingProfile ? null : () => takePhoto('profile'),
                                icon: isUploadingProfile ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3BD0AE))) : const Icon(Icons.photo_camera_back_outlined),
                                label: Text(isUploadingProfile ? 'Subiendo foto...' : '📸 Tomar Foto Oficial (Requerida)'),
                              ),
                              const SizedBox(height: 8),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3BD0AE).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF3BD0AE).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    if (profilePhoto != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(profilePhoto!.path, width: 60, height: 60, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    const Icon(Icons.check_circle, color: Color(0xFF3BD0AE), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Foto oficial lista. Aún debes subir un documento de identificación para completar la validación.',
                                        style: GoogleFonts.publicSans(
                                          color: const Color(0xFF3BD0AE),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                                onPressed: isUploadingProfile ? null : () => takePhoto('profile'),
                                icon: isUploadingProfile ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)) : const Icon(Icons.cameraswitch_outlined),
                                label: Text(isUploadingProfile ? 'Subiendo foto...' : 'Cambiar Foto Oficial'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if ((existingPhotoUrl ?? '').isNotEmpty || isProfileUploaded) ...[
                              if (_needsIdentityDocument) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD600).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFFD600).withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.badge_outlined,
                                        color: Color(0xFFFFD600),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Siguiente paso obligatorio: sube una foto del documento de identificación del jugador (credencial escolar, INE, pasaporte, etc.). Sin esto no podrás finalizar.',
                                          style: GoogleFonts.publicSans(
                                            color: const Color(0xFFFFE066),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (!isDocUploaded) ...[
                                Row(
                                  children: [
                                    Text(
                                      'DOCUMENTO DE IDENTIDAD',
                                      style: GoogleFonts.publicSans(color: Colors.white54, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '* obligatorio',
                                      style: GoogleFonts.publicSans(
                                        color: const Color(0xFFFFD600),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3BD0AE),
                                      foregroundColor: const Color(0xFF0F1722),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: isUploadingDoc ? null : () => takePhoto('doc'),
                                    icon: isUploadingDoc
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF0F1722),
                                            ),
                                          )
                                        : const Icon(Icons.badge_outlined),
                                    label: Text(
                                      isUploadingDoc
                                          ? 'Validando documento...'
                                          : 'Subir documento de identificación',
                                      style: GoogleFonts.publicSans(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3BD0AE).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF3BD0AE).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      if (docPhoto != null) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(docPhoto!.path, width: 60, height: 60, fit: BoxFit.cover),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      const Icon(Icons.check_circle, color: Color(0xFF3BD0AE), size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Documento validado correctamente.',
                                          style: GoogleFonts.publicSans(color: const Color(0xFF3BD0AE), fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                                  onPressed: isUploadingDoc ? null : () => takePhoto('doc'),
                                  icon: isUploadingDoc ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)) : const Icon(Icons.cameraswitch_outlined),
                                  label: Text(isUploadingDoc ? 'Revalidando...' : 'Cambiar Documento'),
                                ),
                                const SizedBox(height: 8),
                              ],
                              DropdownButtonFormField<String>(
                                dropdownColor: const Color(0xFF1E2738),
                                style: GoogleFonts.publicSans(color: Colors.white),
                                value: ((int.tryParse(_playerAge) ?? 0) < 18 && docType == 'ine') ? 'school_id' : docType,
                                decoration: _fieldStyle('Tipo de documento', icon: Icons.assignment_outlined),
                                items: [
                                  if ((int.tryParse(_playerAge) ?? 0) >= 18)
                                    const DropdownMenuItem(value: 'ine', child: Text('INE')),
                                  const DropdownMenuItem(value: 'school_id', child: Text('Credencial escolar')),
                                  const DropdownMenuItem(value: 'passport', child: Text('Pasaporte')),
                                  const DropdownMenuItem(value: 'vaccination_card', child: Text('Cartilla de vacunación')),
                                ],
                                onChanged: (v) => setState(() => docType = v ?? 'school_id'),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: termsAccepted,
                                onChanged: (v) => setState(() => termsAccepted = v ?? false),
                                title: Text('Acepto consentimiento legal', style: GoogleFonts.publicSans(color: Colors.white)),
                                side: const BorderSide(color: Color(0xFF3BD0AE)),
                                activeColor: const Color(0xFF3BD0AE),
                                checkColor: const Color(0xFF0F1722),
                              ),
                              const SizedBox(height: 8),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Captura primero la foto oficial del jugador para poder continuar con la identificación.',
                                  style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_step2FinishHint != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _step2FinishHint!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.publicSans(
                                    color: const Color(0xFFFFD600),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3BD0AE),
                                  disabledBackgroundColor: Colors.white12,
                                  disabledForegroundColor: Colors.white38,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isSubmitting || !_canFinishStep2 ? null : submitStep2,
                                child: isSubmitting
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1722)))
                                    : Text(
                                        _canFinishStep2
                                            ? 'Finalizar y Validar Identidad'
                                            : (_needsIdentityDocument
                                                ? 'Sube el documento para continuar'
                                                : 'Completa los requisitos'),
                                        style: GoogleFonts.oswald(
                                          color: const Color(0xFF0F1722),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() => step = 1),
                              child: Text('Volver al paso 1', style: GoogleFonts.publicSans(color: Colors.white54)),
                            ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (isSubmitting || isProcessingCurp)
            ModernLoadingOverlay(text: isProcessingCurp ? 'Validando CURP...' : 'Procesando...'),
        ],
      ),
    );
  }
}
