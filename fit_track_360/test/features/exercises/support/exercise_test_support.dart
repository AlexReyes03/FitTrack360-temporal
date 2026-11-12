import 'dart:convert';

import 'package:fit_track_360/core/session_storage.dart';
import 'package:http/http.dart' as http;

/// Sesión en memoria para no tocar `flutter_secure_storage` en pruebas.
class FakeSessionStorage implements SessionStorage {
  FakeSessionStorage({this.accessToken = 'access', this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

/// Respuesta JSON con UTF-8 explícito (la atribución lleva `©` y un guion largo).
http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// Ejercicio de prueba; solo existe en pruebas y omite los campos nulos.
Map<String, dynamic> exerciseJson({
  String id = '0001',
  String name = '3/4 sit-up',
  String? nameEs,
  String bodyPart = 'waist',
  String equipment = 'body weight',
  String target = 'abs',
  String imageFile = '0001-2gPfomN.jpg',
  String gifFile = '0001-2gPfomN.gif',
  String attribution = '© Gym visual — https://gymvisual.com/',
  String? level,
  String? instructionsEs,
  List<String>? instructionStepsEs,
  List<String>? secondaryMuscles,
  String? muscleGroup,
  String? commonErrors,
  String? category,
  String? mediaId,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'bodyPart': bodyPart,
    'equipment': equipment,
    'target': target,
    'imageFile': imageFile,
    'gifFile': gifFile,
    'attribution': attribution,
    'nameEs': ?nameEs,
    'level': ?level,
    'instructionsEs': ?instructionsEs,
    'instructionStepsEs': ?instructionStepsEs,
    'secondaryMuscles': ?secondaryMuscles,
    'muscleGroup': ?muscleGroup,
    'commonErrors': ?commonErrors,
    'category': ?category,
    'mediaId': ?mediaId,
  };
}

/// Sobre provisional que se espera del backend para listar ejercicios.
Map<String, dynamic> pageJson(
  List<Map<String, dynamic>> items, {
  int? total,
  int page = 1,
  int pageSize = 20,
}) {
  return <String, dynamic>{
    'items': items,
    'total': total ?? items.length,
    'page': page,
    'pageSize': pageSize,
  };
}
