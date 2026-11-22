import 'dart:convert';

import 'package:fit_track_360/core/network/api_client.dart';
import 'package:fit_track_360/core/session_storage.dart';
import 'package:fit_track_360/features/notifications/data/notifications_api_repository.dart';
import 'package:fit_track_360/features/notifications/domain/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeSessionStorage implements SessionStorage {
  _FakeSessionStorage({this.refreshToken});

  String? accessToken = 'token';
  final String? refreshToken;

  @override
  Future<String?> readAccessToken({bool forceRefresh = false}) async =>
      forceRefresh ? refreshToken : accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {
    accessToken = null;
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

NotificationsApiRepository _repo(
  MockClient client, {
  _FakeSessionStorage? storage,
}) => NotificationsApiRepository(
  ApiClient(storage: storage ?? _FakeSessionStorage(), httpClient: client),
);

Map<String, dynamic> _notificationJson({
  String id = 'n1',
  String title = 'Aviso',
  String message = 'Mensaje',
  String type = 'reminder',
  bool isRead = false,
  String createdAt = '2026-11-22T10:00:00.000Z',
}) => {
  'id': id,
  'title': title,
  'body': message,
  'type': type,
  'isRead': isRead,
  'createdAt': createdAt,
};

void main() {
  test('lista directa, parsea body/message y envía el Bearer', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return _json([
          _notificationJson(
            id: 'n1',
            title: 'Nuevo inicio',
            message: 'Cuerpo del aviso',
            type: 'new_login',
          ),
          {
            'id': 'n2',
            'title': 'Contraseña',
            'message': 'Cambiada',
            'type': 'passwordChanged',
            'isRead': true,
            'createdAt': '2026-11-22T09:00:00.000Z',
            'readAt': '2026-11-22T09:05:00.000Z',
            'deeplink': '/settings',
          },
        ]);
      }),
    );

    final result = await repo.fetchNotifications();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/notifications');
    expect(captured.headers['Authorization'], 'Bearer token');
    expect(result, hasLength(2));
    expect(result[0].message, 'Cuerpo del aviso');
    expect(result[0].type, AppNotificationType.newLogin);
    expect(result[1].message, 'Cambiada');
    expect(result[1].type, AppNotificationType.passwordChanged);
    expect(result[1].readAt, DateTime.parse('2026-11-22T09:05:00.000Z'));
    expect(result[1].targetRoute, '/settings');
  });

  for (final wrapper in ['items', 'data']) {
    test('acepta la lista paginada dentro de "$wrapper"', () async {
      final repo = _repo(
        MockClient(
          (request) async => _json({
            wrapper: [_notificationJson(id: 'n-$wrapper')],
          }),
        ),
      );

      final result = await repo.fetchNotifications();

      expect(result.single.id, 'n-$wrapper');
    });
  }

  test('envía los filtros isRead y type como query params', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return _json([]);
      }),
    );

    await repo.fetchNotifications(
      isRead: false,
      type: AppNotificationType.newLogin,
    );

    expect(captured.url.queryParameters, {
      'isRead': 'false',
      'type': 'new_login',
    });
  });

  test('unread-count lee unreadCount, count o un entero escalar', () async {
    final cases = <({Object body, int expected})>[
      (body: {'unreadCount': 4}, expected: 4),
      (body: {'count': 7}, expected: 7),
      (body: 3, expected: 3),
    ];

    for (final item in cases) {
      final repo = _repo(MockClient((request) async => _json(item.body)));
      expect(await repo.fetchUnreadCount(), item.expected);
    }
  });

  test('PATCH /:id/read envía isRead y devuelve la notificación', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return _json(_notificationJson(id: 'n1', isRead: true));
      }),
    );

    final updated = await repo.updateRead('n1', isRead: true);

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/notifications/n1/read');
    expect(jsonDecode(captured.body), {'isRead': true});
    expect(updated?.id, 'n1');
    expect(updated?.isRead, isTrue);
  });

  test('updateRead acepta 204 sin cuerpo y devuelve null', () async {
    final repo = _repo(MockClient((request) async => http.Response('', 204)));

    expect(await repo.updateRead('n1', isRead: false), isNull);
  });

  test('updateRead con 404 lanza NotificationNotFoundException (S4)', () async {
    final repo = _repo(MockClient((request) async => http.Response('', 404)));

    await expectLater(
      repo.updateRead('ajena', isRead: true),
      throwsA(isA<NotificationNotFoundException>()),
    );
  });

  test('PATCH /read-all marca todas como leídas', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await repo.markAllAsRead();

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/notifications/read-all');
  });

  test('DELETE /:id codifica el id y acepta 204', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await repo.deleteNotification('n:1/abc');

    expect(captured.method, 'DELETE');
    expect(captured.url.pathSegments.last, 'n:1/abc');
  });

  test(
    'deleteNotification con 404 lanza NotificationNotFoundException',
    () async {
      final repo = _repo(MockClient((request) async => http.Response('', 404)));

      await expectLater(
        repo.deleteNotification('ajena'),
        throwsA(isA<NotificationNotFoundException>()),
      );
    },
  );

  test('DELETE /notifications elimina todas', () async {
    late http.Request captured;
    final repo = _repo(
      MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      }),
    );

    await repo.deleteAll();

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/v1/notifications');
  });

  test('propaga SessionExpiredException cuando el refresh falla', () async {
    final storage = _FakeSessionStorage(refreshToken: null);
    final repo = _repo(
      MockClient((request) async => http.Response('', 401)),
      storage: storage,
    );

    await expectLater(
      repo.fetchNotifications(),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(storage.accessToken, isNull);
  });

  test('un error HTTP se convierte en NotificationsApiException', () async {
    final repo = _repo(
      MockClient((request) async => _json({'message': 'fallo interno'}, 500)),
    );

    await expectLater(
      repo.fetchNotifications(),
      throwsA(
        isA<NotificationsApiException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having((error) => error.message, 'message', 'fallo interno'),
      ),
    );
  });

  test(
    'una respuesta sin lista reconocible lanza NotificationsApiException',
    () async {
      final repo = _repo(
        MockClient((request) async => _json({'unexpected': []})),
      );

      await expectLater(
        repo.fetchNotifications(),
        throwsA(isA<NotificationsApiException>()),
      );
    },
  );

  test('AppNotification.fromJson tolera variantes de tipo y campos', () {
    final cases = <String, AppNotificationType>{
      'new_login': AppNotificationType.newLogin,
      'newLogin': AppNotificationType.newLogin,
      'NEW_LOGIN': AppNotificationType.newLogin,
      'security': AppNotificationType.newLogin,
      'password_changed': AppNotificationType.passwordChanged,
      'passwordChanged': AppNotificationType.passwordChanged,
      'PASSWORD_CHANGED': AppNotificationType.passwordChanged,
      'reminder': AppNotificationType.reminder,
      'daily_reminder': AppNotificationType.reminder,
      'REMINDER': AppNotificationType.reminder,
      'desconocido': AppNotificationType.reminder,
    };

    for (final entry in cases.entries) {
      final notification = AppNotification.fromJson({
        'id': 7,
        'title': 'Título',
        'message': 'Cuerpo alterno',
        'type': entry.key,
        'is_read': true,
        'created_at': '2026-11-22T10:00:00.000Z',
        'read_at': '2026-11-22T10:05:00.000Z',
        'deeplink': '/profile',
      });

      expect(notification.id, '7', reason: entry.key);
      expect(notification.message, 'Cuerpo alterno', reason: entry.key);
      expect(notification.type, entry.value, reason: entry.key);
      expect(notification.isRead, isTrue, reason: entry.key);
      expect(notification.readAt, isNotNull, reason: entry.key);
      expect(notification.targetRoute, '/profile', reason: entry.key);
    }
  });
}
