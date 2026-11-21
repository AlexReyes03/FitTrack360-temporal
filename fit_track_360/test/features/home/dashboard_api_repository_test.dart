import 'dart:convert';

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
}
