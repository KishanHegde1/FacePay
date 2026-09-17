import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/design.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static const logoDuration = Duration(seconds: 2);
  static const splashDuration = Duration(seconds: 3);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  Timer? _logoTimer;
  Timer? _completionTimer;
  bool _showSplash = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: SplashScreen.splashDuration,
    );
    _logoTimer = Timer(SplashScreen.logoDuration, () {
      if (!mounted) return;
      setState(() => _showSplash = true);
      if (!MediaQuery.disableAnimationsOf(context)) _animation.forward();
    });
    _completionTimer = Timer(
      SplashScreen.logoDuration + SplashScreen.splashDuration,
      () {
        if (mounted) widget.onComplete();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_showSplash &&
        !_animation.isAnimating &&
        _animation.value == 0) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _logoTimer?.cancel();
    _completionTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_showSplash
      ? Scaffold(
          key: const ValueKey('startup-logo'),
          backgroundColor: const Color(0xFFF7F7FC),
          body: Center(
            child: Semantics(
              label: 'FacePay',
              child: const FacePayLogo(size: 112, showName: false),
            ),
          ),
        )
      : Scaffold(
          key: const ValueKey('startup-splash'),
          backgroundColor: const Color(0xFF171735),
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 0.9,
                colors: [Color(0xFF32235F), Color(0xFF171735)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _animation,
                          curve: const Interval(0, 0.55, curve: Curves.easeOut),
                        ),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.88, end: 1).animate(
                            CurvedAnimation(
                              parent: _animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFF8471B9,
                                ).withValues(alpha: 0.25),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x225E37C6),
                                  blurRadius: 80,
                                  spreadRadius: 28,
                                ),
                              ],
                            ),
                            child: const FacePayLogo(
                              size: 78,
                              showName: false,
                              light: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'FacePay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A familiar face. A simpler way to pay.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB7AFD0),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 43),
                      SizedBox(
                        width: 96,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) => LinearProgressIndicator(
                            value: _animation.value,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(8),
                            backgroundColor: const Color(0xFF3B3156),
                            color: const Color(0xFFC4B4F8),
                            semanticsLabel: 'Opening FacePay',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'MADE FOR YOUR EVERYDAY',
                        style: TextStyle(
                          color: Color(0xFF8B819F),
                          fontSize: 8,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
}
