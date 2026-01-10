import 'package:flutter/material.dart';

import 'features/auth/ui/login_page.dart';

class App extends StatelessWidget {
	const App({super.key});

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			debugShowCheckedModeBanner: false,
			theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
			home: const LoginPage(),
		);
	}
}

