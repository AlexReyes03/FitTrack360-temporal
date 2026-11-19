import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';

void main() {
  test('geolocator y pedometer resuelven en el grafo de dependencias', () {
    expect(LocationAccuracy.low, isNotNull);
    expect(StepCount, isNotNull);
  });
}
