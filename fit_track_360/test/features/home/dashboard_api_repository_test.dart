import 'dart:convert';

import 'package:fit_track_360/features/auth/data/auth_api.dart';
import 'package:fit_track_360/features/home/data/dashboard_api_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('GET dashboard/today con date y utcOffsetMinutes', () async {
    String? calledPath;
    final repo = DashboardApiRepository(
      get: (path) async {
        calledPath = path;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'date': '2026-11-10',
              'utcOffsetMinutes': -360,
              'nutrition': {
                'mealsLogged': 0,
                'consumed': {
                  'calories': 0,
                  'proteinG': 0,
                  'carbsG': 0,
                  'fatG': 0,
                },
                'goals': {
                  'dailyCalorieGoal': 2000,
                  'proteinGoalG': 150,
                  'carbsGoalG': 200,
                  'fatGoalG': 60,
                },
                'remaining': {
                  'calories': 2000,
                  'proteinG': 150,
                  'carbsG': 200,
                  'fatG': 60,
                },
              },
              'session': null,
              'latestMetric': null,
            }),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );

    final today = await repo.today(date: '2026-11-10', utcOffsetMinutes: -360);

    expect(
      calledPath,
      '/api/v1/dashboard/today?date=2026-11-10&utcOffsetMinutes=-360',
    );
    expect(today.date, '2026-11-10');
    expect(today.session, isNull);
    expect(today.latestMetric, isNull);
    expect(today.nutrition.goals.dailyCalorieGoal, 2000);
  });

  Map<String, dynamic> nutritionJson() => {
    'mealsLogged': 2,
    'consumed': {'calories': 1200.5, 'proteinG': 80, 'carbsG': 130, 'fatG': 40},
    'goals': {
      'dailyCalorieGoal': 2000,
      'proteinGoalG': 150,
      'carbsGoalG': 200,
      'fatGoalG': 60,
    },
    'remaining': {'calories': 799.5, 'proteinG': 70, 'carbsG': 70, 'fatG': 20},
  };

  test(
    'parsea sesión y última métrica cuando vienen en la respuesta',
    () async {
      final repo = DashboardApiRepository(
        get: (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'date': '2026-11-21',
              'utcOffsetMinutes': -360,
              'nutrition': nutritionJson(),
              'session': {
                'id': 'ws-1',
                'startedAt': '2026-11-21T14:00:00.000Z',
                'endedAt': '2026-11-21T15:05:00.000Z',
                'notes': 'Pierna',
                'isToday': true,
              },
              'latestMetric': {
                'id': 'bm-1',
                'measuredAt': '2026-11-20T13:00:00.000Z',
                'weightKg': 72.4,
                'bodyFatPercent': 18,
                'waistCm': null,
              },
            }),
          ),
          200,
        ),
      );

      final today = await repo.today(
        date: '2026-11-21',
        utcOffsetMinutes: -360,
      );

      expect(today.nutrition.mealsLogged, 2);
      expect(today.nutrition.consumed.calories, 1200.5);
      final session = today.session!;
      expect(session.id, 'ws-1');
      expect(session.startedAt, DateTime.utc(2026, 11, 21, 14));
      expect(session.endedAt, DateTime.utc(2026, 11, 21, 15, 5));
      expect(session.notes, 'Pierna');
      expect(session.isToday, isTrue);
      final metric = today.latestMetric!;
      expect(metric.id, 'bm-1');
      expect(metric.measuredAt, DateTime.utc(2026, 11, 20, 13));
      expect(metric.weightKg, 72.4);
      expect(metric.bodyFatPercent, 18.0);
      expect(metric.waistCm, isNull);
      expect(metric.hasDisplayValue, isTrue);
    },
  );

  test(
    'una respuesta distinta de 200 lanza AuthApiException con el mensaje',
    () async {
      final repo = DashboardApiRepository(
        get: (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'utcOffsetMinutes inválido'})),
          400,
        ),
      );

      await expectLater(
        repo.today(date: '2026-11-21', utcOffsetMinutes: 9999),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.message,
            'message',
            'utcOffsetMinutes inválido',
          ),
        ),
      );
    },
  );
}
