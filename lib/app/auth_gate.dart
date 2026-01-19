import 'package:flutter/material.dart';
import 'package:insight/features/auth/data/auth_service.dart';
import 'package:insight/features/auth/ui/login_page.dart';
import 'package:insight/features/home/ui/home_page.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Logged in -> Home
        if (snapshot.hasData) {
          return HomePage(onLogout: () async => _auth.signOut());
        }

        // Logged out -> Login
        return const LoginPage();
      },
    );
  }
}
