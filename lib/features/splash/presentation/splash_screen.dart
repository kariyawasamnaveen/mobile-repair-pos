import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/auth/presentation/auth_gate.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isInitDone = false;
  bool _isAnimationDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _isAnimationDone = true;
        });
        _checkAndNavigate();
      }
    });

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // We wait for the auth state to load or any other critical init.
    // Riverpod initialization happens automatically, but we can wait for auth.
    // We add a tiny delay just to ensure the UI has time to build if auth is instant.
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isInitDone = true;
      });
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    // Navigate ONLY when BOTH animation and initialization are done, 
    // to prevent jarring cuts, but do NOT artificially delay if both are fast.
    if (_isInitDone && _isAnimationDone && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0EA5A5), // Solid teal background
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: const _SplashLogoWidget(),
          ),
        ),
      ),
    );
  }
}

class _SplashLogoWidget extends StatelessWidget {
  const _SplashLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shop awning base
              const Positioned(
                bottom: 20,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 110,
                  color: Colors.white,
                ),
              ),
              // Chart / upward trend element overlapping
              Positioned(
                right: 10,
                top: 20,
                child: Stack(
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 70,
                      color: Color(0xFFF59E0B),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        size: 32,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ShopSense',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
