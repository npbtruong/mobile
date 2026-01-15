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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final userJson = prefs.getString('user_email');
    final userName = prefs.getString('user_name');
    final userId = prefs.getInt('user_id');

    if (token != null && userJson != null) {
      _user = {
        'id': userId,
        'name': userName,
        'email': userJson,
      };
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
      await prefs.setString('access_token', response['access_token']);
      await prefs.setString('refresh_token', response['refresh_token']);
      await prefs.setString('user_email', response['user']['email']);
      await prefs.setString('user_name', response['user']['name']);
      await prefs.setInt('user_id', response['user']['id']);

      _user = response['user'];
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
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_id');

    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
