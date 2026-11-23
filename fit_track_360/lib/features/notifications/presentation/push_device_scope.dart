import 'package:flutter/widgets.dart';

import '../data/push_device_lifecycle_service.dart';

/// Expone el [PushDeviceLifecycle] único de la app para que el shell, el
/// perfil y el logout compartan la misma instancia y la misma suscripción a
/// `onTokenRefresh`.
class PushDeviceScope extends InheritedWidget {
  const PushDeviceScope({
    super.key,
    required this.service,
    required super.child,
  });

  final PushDeviceLifecycle service;

  static PushDeviceLifecycle? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<PushDeviceScope>()?.service;
  }

  @override
  bool updateShouldNotify(PushDeviceScope oldWidget) =>
      service != oldWidget.service;
}
