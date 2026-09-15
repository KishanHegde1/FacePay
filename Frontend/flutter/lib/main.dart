import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_api.dart';
import 'services/session_store.dart';
import 'data/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/app_shell.dart';
import 'ui/design.dart';

void main() => runApp(const FacePaymentApp());

class FacePaymentApp extends StatefulWidget {
  const FacePaymentApp({super.key, this.authService, this.sessionStore});
  final AuthService? authService;
  final SessionStore? sessionStore;
  @override
  State<FacePaymentApp> createState() => _FacePaymentAppState();
}

class _FacePaymentAppState extends State<FacePaymentApp> {
  AppState _state = AppState();
  bool _splash = true, _busy = true;
  String? _error;
  Future<void> Function()? _retry;
  late final AuthService _auth = widget.authService ?? HttpAuthService();
  late final SessionStore _store = widget.sessionStore ?? SecureSessionStore();
  final _navigatorKey = GlobalKey<NavigatorState>();
  AuthSession? _session;
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  void _accept(AuthSession session) {
    _session = session;
    _profile = ProfileData(
      id: session.userId,
      mobileNo: session.phone,
      name: session.name,
      email: session.email,
    );
    _state.updateProfile(name: session.name, email: session.email);
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _error = error is AuthFailure ? error.message : message;
        _retry = () => _run(action, message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() => _run(() async {
    final token = await _store.readToken();
    if (token == null) return;
    try {
      final session = await _auth.getCurrentUser(token);
      if (mounted) _accept(session);
    } on AuthFailure catch (error) {
      if (!error.sessionRejected) rethrow;
      await _store.clear();
    }
  }, 'We could not restore your account. Check your connection and try again.');

  Future<void> _signIn(AuthSession session) => _run(() async {
    await _store.saveToken(session.accessToken);
    if (mounted) _accept(session);
  }, 'We could not securely save your login. Please try again.');

  Future<void> _signOut() => _run(() async {
    final session = _session;
    await _store.clear();
    if (!mounted) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    final previous = _state;
    _session = null;
    _profile = null;
    _state = AppState();
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    if (session != null) {
      unawaited(_auth.logout(session.accessToken).catchError((Object _) {}));
    }
  }, 'We could not clear your saved login. Please retry signing out.');

  Future<void> _useAnotherAccount() async {
    try {
      await _store.clear();
      if (!mounted) return;
      setState(() {
        _session = null;
        _profile = null;
        _error = null;
        _retry = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'We could not clear your saved login. Please try again.';
        });
      }
    }
  }

  Future<ProfileData> _saveProfile(String name, String email) async {
    final session = _session!;
    try {
      final profile = await _auth.saveProfile(session.accessToken, name, email);
      if (mounted && _session == session) {
        setState(() => _profile = profile);
        _state.updateProfile(name: profile.name, email: profile.email);
      }
      return profile;
    } on AuthFailure catch (error) {
      if (error.sessionRejected) await _signOut();
      rethrow;
    }
  }

  @override
  void dispose() {
    _auth.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: 'FacePay — payments, with a smile',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: _splash
        ? SplashScreen(
            onComplete: () {
              if (mounted) setState(() => _splash = false);
            },
          )
        : _busy
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _error != null
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'We could not restore your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your saved login is still kept on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _useAnotherAccount,
                      child: const Text('Sign in with another account'),
                    ),
                  ],
                ),
              ),
            ),
          )
        : _session != null
        ? AppShell(
            state: _state,
            profile: _profile,
            onSaveProfile: _saveProfile,
            onSignOut: _signOut,
          )
        : AuthScreen(authService: _auth, onAuthenticated: _signIn),
  );
}
