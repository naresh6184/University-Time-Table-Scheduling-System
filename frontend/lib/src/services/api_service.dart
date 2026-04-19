import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:university_timetable_frontend/src/features/sessions/session_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000',
      connectTimeout: const Duration(minutes: 60),
      receiveTimeout: const Duration(minutes: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Key': 'unischeduler-desktop-client-2026',
      },
    ),
  );

  // Add interceptors to automatically inject the session_id query parameter
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        final activeSession = ref.read(activeSessionProvider);
        if (activeSession != null) {
          options.queryParameters['session_id'] = activeSession.sessionId;
        }
      } catch (_) {}
      return handler.next(options);
    },
  ));

  dio.interceptors.add(LogInterceptor(responseBody: false, requestBody: false));

  // Extract human-readable error messages from FastAPI responses
  dio.interceptors.add(InterceptorsWrapper(
    onError: (DioException error, handler) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        final detail = data['detail'];
        final message = detail is String ? detail : detail.toString();
        return handler.reject(DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: message,
          message: message,
        ));
      }
      return handler.next(error);
    },
  ));

  return dio;
});

class ApiService {
  final Dio _dio;
  ApiService(this._dio);

  String get baseUrl => _dio.options.baseUrl;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    return await _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await _dio.put(path, data: data, queryParameters: queryParameters, options: options);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    return await _dio.delete(path, data: data, queryParameters: queryParameters, options: options);
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiService(dio);
});
