import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_api.dart';

class AuthController extends ChangeNotifier {
  final AuthApi _authApi;

  AuthController(this._authApi);

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      _user = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Verify token và lấy thông tin user từ API
    try {
      final response = await _authApi.getProfile();
      _user = response['user'];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Token hết hạn (401) → logout
      await logout();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authApi.login(email, password);
      final prefs = await SharedPreferences.getInstance();

      // Chỉ lưu access_token, KHÔNG lưu user info
      await prefs.setString('access_token', response['access_token']);

      // Lấy thông tin user từ API
      final profileResponse = await _authApi.getProfile();
      _user = profileResponse['user'];

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
