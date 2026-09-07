import 'package:flutter/material.dart';

import '../pages/home_page.dart';

/// Regresa a la pantalla anterior o, si no hay historial (deep link / refresh), va a Home.
void popOrGoHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushNamedAndRemoveUntil(HomePage.route, (_) => false);
}
