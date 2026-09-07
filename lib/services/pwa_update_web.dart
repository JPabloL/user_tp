import 'dart:html' as html;
import 'dart:js' as js;

/// Enlaza eventos de la app Flutter con el verificador JS en index.html.
void initPwaUpdateBridge() {
  html.document.onVisibilityChange.listen((_) {
    if (html.document.hidden == true) return;
    _invokeCheck();
  });

  // Primer arranque tras hot reload / navegación interna prolongada.
  Future<void>.delayed(const Duration(seconds: 30), _invokeCheck);
}

void _invokeCheck() {
  final check = js.context['__checkPwaUpdate'];
  if (check != null) {
    check.apply([]);
  }
}
