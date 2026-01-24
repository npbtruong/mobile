import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late final Dio _dio;
  void Function()? onUnauthorized;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://10.0.2.2:8000/api',
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _addAuthToken,
      onError: _handleUnauthorized,
    ));
  }

  Future<void> _addAuthToken(RequestOptions options, RequestInterceptorHandler handler) async {
    // Không cần token cho login
    if (options.path == '/auth/login') {
      return handler.next(options);
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _handleUnauthorized(DioException error, ErrorInterceptorHandler handler) async {
    // Nếu 401 (token hết hạn) → xóa token và logout
    if (error.response?.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      onUnauthorized?.call();
    }
    handler.next(error);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Không thể kết nối đến máy chủ';
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get(path);
      return response.data;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Không thể kết nối đến máy chủ';
    }
  }
}
