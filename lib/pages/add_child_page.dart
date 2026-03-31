import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/curp_service.dart';
import '../services/toast_service.dart';
import 'home_page.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({
    super.key,
    required this.api,
    required this.curpService,
    required this.parentId,
    this.prefillCurp,
    this.initialChild,
  });

  static const String route = '/jugador-nuevo';

  final ApiService api;
  final CurpService curpService;
  final String parentId;
  final String? prefillCurp;
  final Map<String, dynamic>? initialChild;

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
  int ocrAttempts = 0;
  String existingTutorName = '';
  String docType = 'school_id';
  String? createdPlayerId;
  String? existingPhotoUrl;
  XFile? profilePhoto;
  XFile? docPhoto;

  final curpCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final aliasCtrl = TextEditingController();
  final apPaCtrl = TextEditingController();
  final apMaCtrl = TextEditingController();
  final bdCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final numberCtrl = TextEditingController();
  final positionsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final hasInitialChild = widget.initialChild != null;
    if (hasInitialChild) {
      final child = widget.initialChild!;
      createdPlayerId = child['_id']?.toString();
      lockPersonalFields = true;
      isIdentityVerified = (child['identity_status']?.toString() == 'verified');
      curpCtrl.text = (child['curp']?.toString() ?? '').toUpperCase();
      _fillFormWithData(child);
      existingPhotoUrl = child['photo']?.toString();
      if (!isIdentityVerified && createdPlayerId != null) {
        step = 2;
      }
    }
    if (!hasInitialChild && (widget.prefillCurp ?? '').isNotEmpty) {
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
    super.dispose();
  }

  Future<void> validateCurpLogic() async {
    final curpInput = curpCtrl.text.trim().toUpperCase();
    if (curpInput.length != 18) return;
    setState(() => isProcessingCurp = true);
    try {
      final res = await widget.curpService.getDetails(curpInput);
      isClaimMode = false;
      final source = res['source']?.toString();
      if (source == 'player_exists') {
        final data = (res['data'] as Map<String, dynamic>?) ?? {};
        final currentTutorId = data['tutor']?['id']?.toString();
        createdPlayerId = res['playerId']?.toString();
        _fillFormWithData(data);
        lockPersonalFields = true;
        isIdentityVerified = (data['identity_status']?.toString() == 'verified');
        existingPhotoUrl = data['photo']?.toString();
        if (currentTutorId == widget.parentId) {
          if (isIdentityVerified) {
            _toast('Perfil ya validado. Solo actualiza jersey y posiciones.');
          } else {
            _toast('Registro previo recuperado. Continua la validacion.');
          }
        } else {
          isClaimMode = true;
          existingTutorName = res['tutorName']?.toString() ?? 'Otro tutor';
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
      _toast('Error consultando CURP', isError: true);
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
    positionsCtrl.text = positions is List ? positions.join(',') : (positions?.toString() ?? '');
  }

  Future<void> submitStep1() async {
    if (nameCtrl.text.trim().isEmpty) return _toast('Faltan datos personales', isError: true);
    if (numberCtrl.text.trim().isEmpty) return _toast('Ingresa el número de jersey', isError: true);
    if (positionsCtrl.text.trim().isEmpty) return _toast('Selecciona una posición', isError: true);

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
      _toast(_friendlyError(e), isError: true);
    }
    if (mounted) setState(() => isSubmitting = false);
  }

  Future<void> takePhoto(String type) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() {
      if (type == 'profile') {
        profilePhoto = file;
      } else {
        docPhoto = file;
      }
    });
  }

  Future<void> submitStep2() async {
    if (createdPlayerId == null) return _toast('No se encontró ID de jugador', isError: true);
    final hasRoster = profilePhoto != null || (existingPhotoUrl ?? '').isNotEmpty;
    if (!hasRoster) return _toast('Falta la foto de perfil (Roster)', isError: true);
    if (docPhoto == null) return _toast('Falta la foto del documento', isError: true);
    if (!termsAccepted) return _toast('Debes aceptar consentimiento legal', isError: true);

    setState(() => isSubmitting = true);
    try {
      if (profilePhoto != null) {
        await widget.api.uploadChildRosterPhoto(
          playerId: createdPlayerId!,
          bytes: await profilePhoto!.readAsBytes(),
        );
      }
      final resValidation = await widget.api.validateChildIdentity(
        playerId: createdPlayerId!,
        docBytes: await docPhoto!.readAsBytes(),
        docType: docType,
      );
      if (resValidation['status'] == 'ok') {
        await _showAlert('Registro exitoso', 'La identidad del jugador fue validada.');
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
      } else {
        ocrAttempts++;
        if (ocrAttempts >= 2) {
          await _showManualReviewOption();
          return;
        }
        _showAlert('Validación fallida', (resValidation['message'] ?? 'Intenta de nuevo').toString());
      }
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    }
    if (mounted) setState(() => isSubmitting = false);
  }

  Future<void> _showManualReviewOption() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Problemas técnicos'),
        content: const Text('Deseas enviarlo a revisión manual?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Intentar otra vez')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await executeManualUpload();
            },
            child: const Text('Enviar a revisión'),
          ),
        ],
      ),
    );
  }

  Future<void> executeManualUpload() async {
    if (createdPlayerId == null || docPhoto == null) return;
    try {
      await widget.api.requestManualReview(
        playerId: createdPlayerId!,
        docBytes: await docPhoto!.readAsBytes(),
        docType: docType,
      );
      _toast('Solicitud enviada. Perfil en revisión.');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.route, (_) => false);
    } catch (e) {
      _toast(_friendlyError(e), isError: true);
    }
  }

  Future<void> _showAlert(String title, String msg) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
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
    ToastService.show(context, msg, isError: isError);
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
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: BorderSide(color: Colors.black, width: 1.2),
      ),
    );
  }

  Widget _stepPill(int index, String text) {
    final active = step == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'TOCHITO PRO',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.1,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6F7680),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Gestion de jugador',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step == 1
                    ? 'Captura datos y verifica CURP.'
                    : 'Sube evidencia para validar identidad.',
                style: const TextStyle(color: Color(0xFF646C76), fontSize: 14),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: curpCtrl,
                              readOnly: lockPersonalFields,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _fieldStyle('CURP (18)', icon: Icons.badge_outlined),
                              onChanged: (_) => validateCurpLogic(),
                            ),
                            if (isClaimMode)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4E5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Jugador registrado por: $existingTutorName',
                                    style: const TextStyle(
                                      color: Color(0xFF9A5C00),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (lockPersonalFields)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F3F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Datos personales bloqueados por CURP validada. Solo puedes editar jersey y posiciones.',
                                    style: TextStyle(
                                      color: Color(0xFF5E6670),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: nameCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle('Nombre', icon: Icons.person_outline),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: aliasCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle('Alias', icon: Icons.tag),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: apPaCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle('Apellido paterno'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: apMaCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle('Apellido materno'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: bdCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle(
                                'Fecha nacimiento YYYY-MM-DD',
                                icon: Icons.calendar_today_outlined,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: genderCtrl,
                              readOnly: lockPersonalFields,
                              decoration: _fieldStyle('Sexo H/M'),
                            ),
                            const SizedBox(height: 8),
                            TextField(controller: numberCtrl, decoration: _fieldStyle('Jersey', icon: Icons.confirmation_number_outlined)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: positionsCtrl,
                              decoration: _fieldStyle('Posiciones (coma)', icon: Icons.sports),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: isSubmitting || isProcessingCurp ? null : submitStep1,
                                child: Text(
                                  isIdentityVerified
                                      ? 'Guardar y volver'
                                      : 'Continuar a validacion',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('step-2'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => takePhoto('profile'),
                              icon: const Icon(Icons.photo_camera_back_outlined),
                              label: Text(
                                profilePhoto != null || existingPhotoUrl != null
                                    ? 'Foto de roster lista'
                                    : 'Subir foto de roster',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => takePhoto('doc'),
                              icon: const Icon(Icons.badge_outlined),
                              label: Text(docPhoto != null ? 'Documento listo' : 'Subir documento'),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: docType,
                              decoration: _fieldStyle('Tipo de documento', icon: Icons.assignment_outlined),
                              items: const [
                                DropdownMenuItem(value: 'school_id', child: Text('Credencial escolar')),
                                DropdownMenuItem(value: 'passport', child: Text('Pasaporte')),
                              ],
                              onChanged: (v) => setState(() => docType = v ?? 'school_id'),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: termsAccepted,
                              onChanged: (v) => setState(() => termsAccepted = v ?? false),
                              title: const Text('Acepto consentimiento legal'),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: isSubmitting ? null : submitStep2,
                                child: const Text('Validar identidad'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() => step = 1),
                              child: const Text('Volver al paso 1'),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          if (isSubmitting || isProcessingCurp)
            const ColoredBox(color: Colors.black26, child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
