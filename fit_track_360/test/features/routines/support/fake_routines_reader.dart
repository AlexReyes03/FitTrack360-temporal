import 'dart:async';

import 'package:fit_track_360/features/routines/data/routines_reader.dart';

class FakeRoutinesReader implements RoutinesReader {
  FakeRoutinesReader({
    this.routines = const [],
    this.detail,
    this.listError,
    this.detailError,
  });

  List<RoutineSummary> routines;
  RoutineDetail? detail;
  Object? listError;
  Object? detailError;
  int listCalls = 0;
  int detailCalls = 0;
  String? lastRequestedId;
  Completer<List<RoutineSummary>>? listGate;
  Completer<RoutineDetail>? detailGate;

  @override
  Future<List<RoutineSummary>> list() {
    listCalls++;
    final gate = listGate;
    if (gate != null) return gate.future;
    final error = listError;
    if (error != null) return Future.error(error);
    return Future.value(routines);
  }

  @override
  Future<RoutineDetail> getById(String id) {
    detailCalls++;
    lastRequestedId = id;
    final gate = detailGate;
    if (gate != null) return gate.future;
    final error = detailError;
    if (error != null) return Future.error(error);
    final value = detail;
    if (value == null) return Future.error(const RoutineNotFoundException());
    return Future.value(value);
  }
}
