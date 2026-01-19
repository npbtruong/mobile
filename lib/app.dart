import 'package:flutter/material.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/ui/login_page.dart';
import 'features/home/ui/home_page.dart';

class App extends StatelessWidget {
  final AuthController authController;

  const App({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return _InheritedAuthController(
      controller: authController,
      child: MaterialApp(
        title: 'Mobile App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: ListenableBuilder(
          listenable: authController,
          builder: (context, child) {
            if (authController.isLoggedIn) {
              return const HomePage();
            }
            return const LoginPage();
          },
        ),
        routes: {
          '/home': (context) => const HomePage(),
          '/login': (context) => const LoginPage(),
        },
      ),
    );
  }
}

class _InheritedAuthController extends InheritedNotifier<AuthController> {
  const _InheritedAuthController({
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedAuthController>()!
        .notifier!;
  }
}

// Export để các file khác có thể sử dụng
typedef InheritedAuthController = _InheritedAuthController;
