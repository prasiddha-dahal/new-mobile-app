import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplash = Duration(milliseconds: 2000);

  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _glow;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _glow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(_textFade);
    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    );

    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final minSplash = Future<void>.delayed(_minSplash);
    final authActions = ref.read(authActionsProvider);

    // 1. Try to restore session
    final tokenResult = await authActions.getStoredToken();
    final token = tokenResult.getOrElse((_) => null);

    if (token != null && token.isNotEmpty) {
      await authActions.getCurrentUser();
      await minSplash;
      if (!mounted) return;
      // Router redirect will send user to correct home based on role
      return;
    }

    // 2. No token → check if onboarding was already seen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    await minSplash;
    if (!mounted) return;

    if (hasSeenOnboarding) {
      context.go('/login');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 0.9,
            colors: [Colors.white, AppColors.cream, AppColors.mist],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),

              // Logo with soft pine glow
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.pinePale.withAlpha(
                        (90 * _glow.value).round(),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(scale: _logoScale, child: child),
                    ),
                  );
                },
                child: SvgPicture.asset(
                  'assets/images/sahayatri-logo.svg',
                  height: 88,
                  semanticsLabel: 'Sahayatri logo',
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Name + tagline
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: const Column(
                    children: [
                      Text(
                        'Physioghar',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.pine,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Physiotherapy care\nfor a healthier tomorrow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: AppColors.inkMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 4),

              // Subtle loader, fades in last
              FadeTransition(
                opacity: _loaderFade,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.pineLight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
