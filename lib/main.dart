import 'package:flutter/material.dart';
import 'app.dart';
import 'core/services/api_service.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/logic/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  final authApi = AuthApi(apiService);
  final authController = AuthController(authApi);

  await authController.checkAuthStatus();

  runApp(App(authController: authController));
}
