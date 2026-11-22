import 'package:flutter/widgets.dart';

import 'notifications_view_model.dart';

/// Expone el [NotificationsViewModel] de toda la app para que el header del
/// shell, la pantalla de notificaciones y cualquier badge compartan estado.
class NotificationsScope extends InheritedNotifier<NotificationsViewModel> {
  const NotificationsScope({
    super.key,
    required NotificationsViewModel notifier,
    required super.child,
  }) : super(notifier: notifier);

  static NotificationsViewModel of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NotificationsScope>();
    assert(
      scope != null,
      'NotificationsScope no encontrado. Envuelve la app con '
      'NotificationsScope.',
    );
    return scope!.notifier!;
  }

  static NotificationsViewModel? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationsScope>()
        ?.notifier;
  }
}
