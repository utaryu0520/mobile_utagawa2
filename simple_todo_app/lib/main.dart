import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'login_screen.dart';
import 'todo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  await authService.initialize();

  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: authService.isLoggedIn ? const TodoScreen() : const LoginScreen(),
    );
  }
}
