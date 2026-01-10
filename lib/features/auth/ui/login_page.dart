import 'package:flutter/material.dart';

import '../logic/auth_controller.dart';

class LoginPage extends StatefulWidget {
	const LoginPage({super.key});

	@override
	State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
	final _formKey = GlobalKey<FormState>();
	final _emailController = TextEditingController();
	final _passwordController = TextEditingController();

	late final AuthController _authController;

	@override
	void initState() {
		super.initState();
		_authController = AuthController();
	}

	@override
	void dispose() {
		_emailController.dispose();
		_passwordController.dispose();
		_authController.dispose();
		super.dispose();
	}

	Future<void> _onLoginPressed() async {
		final isValid = _formKey.currentState?.validate() ?? false;
		if (!isValid) return;

		await _authController.login(
			email: _emailController.text,
			password: _passwordController.text,
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Login')),
			body: Center(
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 420),
					child: Padding(
						padding: const EdgeInsets.all(16),
						child: AnimatedBuilder(
							animation: _authController,
							builder: (context, _) {
								final isLoading = _authController.isLoading;
								final error = _authController.errorMessage;

								return Form(
									key: _formKey,
									child: Column(
										mainAxisSize: MainAxisSize.min,
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											TextFormField(
												controller: _emailController,
												keyboardType: TextInputType.emailAddress,
												textInputAction: TextInputAction.next,
												enabled: !isLoading,
												decoration: const InputDecoration(
													labelText: 'Email',
													border: OutlineInputBorder(),
												),
												validator: (value) {
													if (value == null || value.trim().isEmpty) {
														return 'Email is required';
													}
													return null;
												},
											),
											const SizedBox(height: 12),
											TextFormField(
												controller: _passwordController,
												obscureText: true,
												textInputAction: TextInputAction.done,
												enabled: !isLoading,
												decoration: const InputDecoration(
													labelText: 'Password',
													border: OutlineInputBorder(),
												),
												validator: (value) {
													if (value == null || value.isEmpty) {
														return 'Password is required';
													}
													return null;
												},
												onFieldSubmitted: (_) => _onLoginPressed(),
											),
											const SizedBox(height: 16),
											SizedBox(
												height: 48,
												child: ElevatedButton(
													onPressed: isLoading ? null : _onLoginPressed,
													child: isLoading
															? const SizedBox(
																	width: 20,
																	height: 20,
																	child: CircularProgressIndicator(strokeWidth: 2),
																)
															: const Text('Login'),
												),
											),
											const SizedBox(height: 12),
											if (error != null)
												Text(
													error,
													style: TextStyle(color: Theme.of(context).colorScheme.error),
													textAlign: TextAlign.center,
												),
										],
									),
								);
							},
						),
					),
				),
			),
		);
	}
}

