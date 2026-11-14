import 'package:fit_track_360/features/routines/presentation/routine_detail_page.dart';
import 'package:fit_track_360/features/routines/presentation/routines_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'fake_routines_reader.dart';

Widget routinesTestApp(
  FakeRoutinesReader reader, {
  String initialLocation = '/app/rutinas',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login')),
      ),
      GoRoute(
        path: '/app/rutinas',
        builder: (context, state) => RoutinesPage(reader: reader),
      ),
      GoRoute(
        path: '/app/rutinas/:id',
        builder: (context, state) => RoutineDetailPage(
          routineId: state.pathParameters['id']!,
          reader: reader,
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}
