import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';

class AuthApi {
	AuthApi({ApiService? apiService}) : _apiService = apiService ?? ApiService();

	final ApiService _apiService;

	Future<String> login({required String email, required String password}) async {
		final json = await _apiService.postJson(
			ApiConstants.loginEndpoint,
			body: <String, dynamic>{
				'email': email,
				'password': password,
			},
		);

		final token = json['token'];
		if (token is String && token.isNotEmpty) {
			return token;
		}

		throw ApiException('Invalid server response');
	}
}

