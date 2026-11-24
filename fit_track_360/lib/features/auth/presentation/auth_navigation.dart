import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Regresa a «Inicia sesión» sin apilar otra copia: si hay pantalla previa
/// (login empujó registro o recuperar) hace `pop`; si no, `go('/login')`.
void backToLogin(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/login');
  }
}
