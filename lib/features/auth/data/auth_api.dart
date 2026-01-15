import '../../../core/services/api_service.dart';

class AuthApi {
  final ApiService _apiService;

  AuthApi(this._apiService);

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await _apiService.post(
      '/auth/login',
      {
        'email': email,
        'password': password,
      },
    );
  }
}
