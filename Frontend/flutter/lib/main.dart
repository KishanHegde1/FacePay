import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'services/auth_api.dart';
import 'services/session_store.dart';
import 'data/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/app_shell.dart';
import 'screens/server_connection_screen.dart';
import 'ui/design.dart';
import 'services/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FacePaymentApp());
}

class FacePaymentApp extends StatefulWidget {
  const FacePaymentApp({
    super.key,
    this.authService,
    this.sessionStore,
    this.initializeServices,
  });
  final AuthService? authService;
  final SessionStore? sessionStore;
  final Future<void> Function()? initializeServices;
  @override
  State<FacePaymentApp> createState() => _FacePaymentAppState();
}

class _FacePaymentAppState extends State<FacePaymentApp> {
  AppState _state = AppState();
  bool _splash = true, _busy = true;
  bool _authReady = false;
  bool _connecting = false, _connectionDelayed = false;
  Timer? _restoreRetryTimer;
  Completer<void>? _restoreRetryWait;
  final AppSettings _settings = AppSettings();
  String? _error;
  Future<void> Function()? _retry;
  late final AuthService _auth;
  late final SessionStore _store = widget.sessionStore ?? SecureSessionStore();
  final _navigatorKey = GlobalKey<NavigatorState>();
  AuthSession? _session;
  ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_settings.load());
    unawaited(_restore());
  }

  Future<void> _initializeAuth() async {
    if (_authReady) return;
    try {
      if (widget.initializeServices != null) {
        await widget.initializeServices!();
      } else if (widget.authService == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        // Initialize alongside the startup presentation instead of holding the
        // native launch screen. Firebase Auth must wait for this to complete.
        await Firebase.initializeApp();
      }
      if (!mounted) return;
      _auth =
          widget.authService ??
          (FirebasePhoneAuthService.isSupported
              ? FirebasePhoneAuthService()
              : HttpAuthService());
      _authReady = true;
    } catch (_) {
      throw const AuthFailure(
        'Phone sign-in could not start. Please try again.',
        code: 'authentication_initialization_failed',
      );
    }
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

  Future<void> _run(
    Future<void> Function() action,
    String message, {
    bool connecting = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _connecting = connecting;
      _connectionDelayed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _error = error is AuthFailure ? error.message : message;
        _connectionDelayed =
            connecting &&
            error is AuthFailure &&
            _temporaryConnectionFailure(error);
        _retry = () => _run(action, message, connecting: connecting);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _temporaryConnectionFailure(AuthFailure error) =>
      !error.sessionRejected &&
      (const {'timeout', 'connection'}.contains(error.code) ||
          const {502, 503, 504}.contains(error.statusCode));

  Future<void> _waitForRestoreRetry(Duration delay) async {
    final wait = Completer<void>();
    _restoreRetryWait = wait;
    _restoreRetryTimer = Timer(delay, wait.complete);
    await wait.future;
    if (identical(_restoreRetryWait, wait)) {
      _restoreRetryWait = null;
      _restoreRetryTimer = null;
    }
  }

  Future<AuthSession?> _restoreSession(String token) async {
    // Retry only the read-only session lookup, never OTP or payment requests.
    // Five 15-second requests plus backoff allow a sleeping server to respond.
    for (var attempt = 0; mounted; attempt++) {
      try {
        return await _auth.getCurrentUser(token);
      } on AuthFailure catch (error) {
        if (!_temporaryConnectionFailure(error) || attempt >= 4) rethrow;
        if (!mounted) return null;
        await _waitForRestoreRetry(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<void> _restore() => _run(
    () async {
      await _initializeAuth();
      if (!mounted) return;
      final token = await _store.readToken();
      if (!mounted || token == null) return;
      try {
        final session = await _restoreSession(token);
        if (mounted && session != null) _accept(session);
      } on AuthFailure catch (error) {
        if (!error.sessionRejected) rethrow;
        if (mounted) await _store.clear();
      }
    },
    'We could not restore your account. Check your connection and try again.',
    connecting: true,
  );

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
    _restoreRetryTimer?.cancel();
    final wait = _restoreRetryWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    _settings.dispose();
    if (_authReady) {
      _auth.dispose();
    } else {
      widget.authService?.dispose();
    }
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSettingsScope(
    settings: _settings,
    child: AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'FacePay — payments, with a smile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settings.themeMode,
        home: Builder(
          builder: (context) => _splash
              ? SplashScreen(
                  onComplete: () {
                    if (mounted) setState(() => _splash = false);
                  },
                )
              : _busy
              ? (_connecting
                    ? const ServerConnectionScreen()
                    : const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      ))
              : _error != null
              ? (_connectionDelayed
                    ? ServerConnectionScreen(waiting: false, onRetry: _retry)
                    : Scaffold(
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _authReady
                                      ? 'We could not restore your account'
                                      : 'We could not start phone sign-in',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: AppPalette.of(context).ink,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppPalette.of(context).muted,
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your saved login is still kept on this device.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppPalette.of(context).muted,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _retry,
                                  child: Text('Try again'),
                                ),
                                if (_authReady) ...[
                                  SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _useAnotherAccount,
                                    child: Text('Sign in with another account'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ))
              : _session != null
              ? AppShell(
                  state: _state,
                  profile: _profile,
                  accessToken: _session!.accessToken,
                  onSaveProfile: _saveProfile,
                  onSignOut: _signOut,
                )
              : AuthScreen(authService: _auth, onAuthenticated: _signIn),
        ),
      ),
    ),
  );
}
