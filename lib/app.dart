import 'package:flutter/material.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/ui/login_page.dart';

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = _InheritedAuthController.of(context);
    final user = authController.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authController.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Đăng nhập thành công!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin người dùng',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'ID', value: user['id']?.toString() ?? '-'),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Tên', value: user['name'] ?? '-'),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Email', value: user['email'] ?? '-'),
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Vai trò', value: user['role'] ?? 'user'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await authController.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
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
