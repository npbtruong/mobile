import 'package:flutter/foundation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../data/auth_api.dart';

class AuthController extends ChangeNotifier {
	AuthController({AuthApi? authApi, ConnectivityService? connectivityService})
			: _authApi = authApi ?? AuthApi(),
				_connectivityService = connectivityService ?? const ConnectivityService();

	final AuthApi _authApi;
	final ConnectivityService _connectivityService;

	bool _isLoading = false;
	String? _errorMessage;

	bool get isLoading => _isLoading;
	String? get errorMessage => _errorMessage;

	Future<void> login({required String email, required String password}) async {
		_errorMessage = null;

		if (email.trim().isEmpty || password.isEmpty) {
			_errorMessage = 'Email and password are required.';
			notifyListeners();
			return;
		}

		_isLoading = true;
		notifyListeners();

		try {
			final hasInternet = await _connectivityService.hasInternetConnection();
			if (!hasInternet) {
				_errorMessage = 'No internet connection.';
				return;
			}

			final token = await _authApi.login(email: email.trim(), password: password);
			debugPrint('AUTH TOKEN: $token');
		} on ApiException catch (e) {
			_errorMessage = e.message;
		} catch (_) {
			_errorMessage = 'Something went wrong. Please try again.';
		} finally {
			_isLoading = false;
			notifyListeners();
		}
	}
}

