import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DryTechApiException implements Exception {
  final String message;
  final int? statusCode;

  const DryTechApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class DryTechApi {
  static const String baseUrl = String.fromEnvironment(
    'DRYTECH_API_URL',
    defaultValue: 'https://api-drytech.onrender.com/api',
  );

  final http.Client _client;
  String? _token;
  DateTime? _tokenExpiresAt;

  DryTechApi({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<void> _ensureMockAdminToken() async {
    final valid = _token != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!);
    if (valid) return;

    http.Response response;
    try {
      response = await _client
          .post(
            _uri('/auth/mock'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      throw DryTechApiException(
        'Não foi possível alcançar a API em $baseUrl. Confira se o backend está rodando.',
      );
    }

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DryTechApiException(
        _messageFrom(decoded, 'A API não liberou a autenticação mock.'),
        response.statusCode,
      );
    }
    if (decoded is! Map || decoded['token'] is! String) {
      throw const DryTechApiException('A API respondeu sem um token administrativo válido.');
    }

    _token = decoded['token'] as String;
    _tokenExpiresAt = DateTime.now().add(const Duration(hours: 11, minutes: 50));
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  String _messageFrom(dynamic data, String fallback) {
    if (data is Map) {
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return fallback;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureMockAdminToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    http.Response response;
    try {
      final uri = _uri(path);
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 12));
          break;
        case 'POST':
          response = await _client.post(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 12));
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 12));
          break;
        default:
          throw ArgumentError('Método HTTP não suportado: $method');
      }
    } catch (error) {
      if (error is DryTechApiException) rethrow;
      throw const DryTechApiException('Falha de comunicação com a API. Confira o servidor e o CORS.');
    }

    final decoded = _decode(response);
    if (response.statusCode == 401) {
      _token = null;
      _tokenExpiresAt = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DryTechApiException(
        _messageFrom(decoded, 'A API retornou o status ${response.statusCode}.'),
        response.statusCode,
      );
    }
    return decoded;
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(value);
  }

  Future<List<Map<String, dynamic>>> getDevices() async =>
      _asList(await _request('GET', '/devices'));

  Future<Map<String, dynamic>> createDevice(Map<String, dynamic> body) async =>
      _asMap(await _request('POST', '/devices', body: body));

  Future<Map<String, dynamic>> getDashboard(String deviceId) async =>
      _asMap(await _request('GET', '/devices/${Uri.encodeComponent(deviceId)}/dashboard'));

  Future<List<Map<String, dynamic>>> getCycles(String deviceId) async =>
      _asList(await _request('GET', '/cycles?deviceId=${Uri.encodeQueryComponent(deviceId)}'));

  Future<Map<String, dynamic>> createCycle(Map<String, dynamic> body) async =>
      _asMap(await _request('POST', '/cycles', body: body));

  Future<Map<String, dynamic>> setCycleStatus(String cycleId, String status) async =>
      _asMap(await _request(
        'PATCH',
        '/cycles/${Uri.encodeComponent(cycleId)}/status',
        body: {'status': status},
      ));

  Future<Map<String, dynamic>> cancelCycle(String cycleId) async =>
      _asMap(await _request('POST', '/cycles/${Uri.encodeComponent(cycleId)}/cancel'));

  Future<List<Map<String, dynamic>>> getAlerts(String deviceId) async =>
      _asList(await _request('GET', '/devices/${Uri.encodeComponent(deviceId)}/alerts?active=true'));

  Future<Map<String, dynamic>> acknowledgeAlert(String alertId) async =>
      _asMap(await _request('PATCH', '/alerts/${Uri.encodeComponent(alertId)}/acknowledge'));
}

class DryTechData extends ChangeNotifier {
  final DryTechApi api;
  DryTechData({DryTechApi? api}) : api = api ?? DryTechApi();

  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> devices = [];
  List<Map<String, dynamic>> cycles = [];
  List<Map<String, dynamic>> alerts = [];
  Map<String, dynamic>? dashboard;
  String? selectedDeviceId;

  Map<String, dynamic>? get selectedDevice {
    for (final device in devices) {
      if (device['id']?.toString() == selectedDeviceId) return device;
    }
    return devices.isEmpty ? null : devices.first;
  }

  Map<String, dynamic>? get telemetry {
    final value = dashboard?['telemetry'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      devices = await api.getDevices();
      if (devices.isEmpty) {
        selectedDeviceId = null;
        cycles = [];
        alerts = [];
        dashboard = null;
      } else {
        final hasSelected = devices.any((d) => d['id']?.toString() == selectedDeviceId);
        if (!hasSelected) selectedDeviceId = devices.first['id']?.toString();
        final id = selectedDeviceId!;
        final results = await Future.wait([
          api.getCycles(id),
          api.getDashboard(id),
          api.getAlerts(id),
        ]);
        cycles = results[0] as List<Map<String, dynamic>>;
        dashboard = results[1] as Map<String, dynamic>;
        alerts = results[2] as List<Map<String, dynamic>>;
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDevice(String deviceId) async {
    selectedDeviceId = deviceId;
    await refresh();
  }

  Future<Map<String, dynamic>> startCycle({
    required String foodName,
    required double initialWeight,
    required double targetTemperature,
    required int plannedDurationSeconds,
  }) async {
    final device = selectedDevice;
    final deviceId = device?['id']?.toString();
    if (deviceId == null || deviceId.isEmpty) {
      throw const DryTechApiException('Cadastre ou selecione uma secadora antes de iniciar um ciclo.');
    }
    final backendCycle = dashboard?['cycle'];
    if (backendCycle is Map) {
      final status = backendCycle['status']?.toString();
      if (status == 'PREPARING' || status == 'DRYING' || status == 'PAUSED') {
        throw const DryTechApiException('Já existe um ciclo ativo para esta secadora. Aguarde ou encerre o ciclo atual.');
      }
    }
    final created = await api.createCycle({
      'deviceId': deviceId,
      'initialWeight': initialWeight,
      'targetHumidity': 15,
      'foodName': foodName,
      'targetTemperature': targetTemperature,
      'plannedDurationSeconds': plannedDurationSeconds,
    });
    final cycleId = created['id']?.toString();
    if (cycleId == null || cycleId.isEmpty) {
      throw const DryTechApiException('A API criou o ciclo, mas não retornou o identificador.');
    }
    // A API mantém o novo ciclo em PREPARING até o hardware confirmar a execução.
    await refresh();
    return created;
  }

  Future<void> updateCycleStatus(String? cycleId, String status) async {
    if (cycleId == null || cycleId.isEmpty) return;
    await api.setCycleStatus(cycleId, status);
    await refresh();
  }

  Future<void> cancelCycle(String? cycleId) async {
    if (cycleId == null || cycleId.isEmpty) return;
    await api.cancelCycle(cycleId);
    await refresh();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await api.acknowledgeAlert(alertId);
    await refresh();
  }

  Future<Map<String, dynamic>> registerDevice({
    required String name,
    required String serialNumber,
    required String apiKey,
  }) async {
    final device = await api.createDevice({
      'name': name,
      'serialNumber': serialNumber,
      'apiKey': apiKey,
      'maxLoadKg': 10,
      'maxCurrent': 10,
    });
    await refresh();
    return device;
  }
}

final dryTechData = DryTechData();
