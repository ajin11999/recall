import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'models.dart';

class Api {
  Api(this.baseUrl, this.token)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ));

  final String baseUrl;
  final String token;
  final Dio _dio;

  static Future<String> login(String baseUrl, String password) async {
    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final res = await dio.post('/api/auth/login', data: {'password': password});
    return (res.data as Map)['token'] as String;
  }

  // ---- items

  Future<ItemPage> items({String? q, int? locationId, int? labelId, bool advanced = false, int page = 1}) async {
    final res = await _dio.get('/api/items', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      'location_id': ?locationId,
      'label_id': ?labelId,
      if (advanced) 'advanced': 'true',
      'page': page,
      'per_page': 100,
    });
    return ItemPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Item> item(int id) async {
    final res = await _dio.get('/api/items/$id');
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Item> createItem(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/items', data: body);
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Item> updateItem(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/api/items/$id', data: body);
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteItem(int id) => _dio.delete('/api/items/$id');

  // ---- locations

  Future<List<Location>> locations() async {
    final res = await _dio.get('/api/locations');
    return (res.data as List)
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Location> createLocation(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/locations', data: body);
    return Location.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Location> updateLocation(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/api/locations/$id', data: body);
    return Location.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteLocation(int id) => _dio.delete('/api/locations/$id');

  // ---- labels

  Future<List<Label>> labels() async {
    final res = await _dio.get('/api/labels');
    return (res.data as List)
        .map((e) => Label.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Label> createLabel(Map<String, dynamic> body) async {
    final res = await _dio.post('/api/labels', data: body);
    return Label.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Label> updateLabel(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/api/labels/$id', data: body);
    return Label.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteLabel(int id) => _dio.delete('/api/labels/$id');

  // ---- photos

  Future<Photo> uploadPhoto(int itemId, Uint8List bytes, String contentType) async {
    final res = await _dio.post(
      '/api/items/$itemId/photos',
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: bytes.length,
      }),
    );
    return Photo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePhoto(int id) => _dio.delete('/api/photos/$id');

  Future<void> reorderPhotos(int itemId, List<int> photoIds) async {
    await _dio.put('/api/items/$itemId/photos/reorder', data: {'photo_ids': photoIds});
  }

  /// Photo URL with the token as a query param, so plain Image widgets can load it.
  String photoUrl(int id) => '$baseUrl/api/photos/$id?token=$token';

  // ---- maintenance

  Future<List<MaintenanceSchedule>> itemMaintenance(int itemId) async {
    final res = await _dio.get('/api/items/$itemId/maintenance');
    return (res.data as List)
        .map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MaintenanceSchedule> createSchedule(int itemId, Map<String, dynamic> body) async {
    final res = await _dio.post('/api/items/$itemId/maintenance', data: body);
    return MaintenanceSchedule.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MaintenanceSchedule> updateSchedule(int id, Map<String, dynamic> body) async {
    final res = await _dio.put('/api/maintenance/$id', data: body);
    return MaintenanceSchedule.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(int id) => _dio.delete('/api/maintenance/$id');

  Future<MaintenanceSchedule> completeSchedule(int id,
      {String? completedAt, String? notes, num? cost}) async {
    final res = await _dio.post('/api/maintenance/$id/complete', data: {
      'completed_at': ?completedAt,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'cost': ?cost,
    });
    return MaintenanceSchedule.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<MaintenanceLog>> scheduleLogs(int id) async {
    final res = await _dio.get('/api/maintenance/$id/logs');
    return (res.data as List)
        .map((e) => MaintenanceLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MaintenanceSchedule>> upcomingMaintenance({int days = 60}) async {
    final res = await _dio.get('/api/maintenance-upcoming', queryParameters: {'days': days});
    return (res.data as List)
        .map((e) => MaintenanceSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

String apiErrorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    if (e.response != null) return 'Request failed (${e.response!.statusCode})';
    return 'Network error — check the server URL and your connection';
  }
  return e.toString();
}
