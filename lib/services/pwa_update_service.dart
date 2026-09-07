import 'pwa_update_stub.dart' if (dart.library.html) 'pwa_update_web.dart' as pwa_update;

/// Registra listeners web para detectar nuevos deploys de la PWA.
void initPwaUpdateBridge() => pwa_update.initPwaUpdateBridge();
