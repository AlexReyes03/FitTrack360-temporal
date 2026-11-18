/// Día calendario en la hora local del dispositivo.
///
/// Cualquier instante (local o UTC, como los que devuelve el API) se
/// normaliza con `toLocal()` antes de tomar año, mes y día.
class LocalDay {
  const LocalDay._(this.year, this.month, this.day);

  factory LocalDay.of(DateTime instant) {
    final local = instant.toLocal();
    return LocalDay._(local.year, local.month, local.day);
  }

  final int year;
  final int month;
  final int day;

  /// `YYYY-MM-DD`, la fecha local explícita que se envía al API.
  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  /// 00:00:00.000 local.
  DateTime get start => DateTime(year, month, day);

  /// 23:59:59.999 local.
  DateTime get end => DateTime(year, month, day, 23, 59, 59, 999);

  bool contains(DateTime instant) => LocalDay.of(instant) == this;

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'LocalDay($key)';
}
