/// Textos de presentación del detalle de sesión (sin lógica de negocio).
library;

String formatDuration(Duration? duration) {
  if (duration == null) return 'En curso';
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}

String formatKg(double kg) {
  final text = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(1);
  return '$text kg';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatSetCount(int count) => count == 1 ? '1 serie' : '$count series';

String _sign(num value) => value > 0 ? '+' : (value < 0 ? '−' : '');

String formatDurationDelta(Duration? delta) {
  if (delta == null) return 'Sin dato';
  final minutes = delta.inMinutes;
  return '${_sign(minutes)}${minutes.abs()} min';
}

String formatKgDelta(double delta) => '${_sign(delta)}${formatKg(delta.abs())}';

String formatIntDelta(int delta) => '${_sign(delta)}${delta.abs()}';
