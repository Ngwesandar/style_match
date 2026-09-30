import 'package:flutter/material.dart';
import 'package:style_match/screen/home_screen.dart';
import 'package:style_match/screen/login_screen.dart';
import 'package:style_match/services/auth_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSessionAndLaunch();
  }

  Future<void> _checkSessionAndLaunch() async {
    // Run session check and minimum branded splash duration in parallel
    final results = await Future.wait([
      AuthService.isLoggedIn(),
      Future.delayed(const Duration(milliseconds: 1400)),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoggedIn = results[0] as bool;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SplashScreen();
    }

    if (_isLoggedIn) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}

/// A minimal, premium splash screen for the "Silent Login" phase.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Theme background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branded Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.checkroom, size: 64, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              "Style Match",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your Personal AI Stylist",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF737373),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF0F766E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
