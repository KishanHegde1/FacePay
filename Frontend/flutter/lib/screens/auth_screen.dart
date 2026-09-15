import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_api.dart';
import '../ui/design.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.onAuthenticated,
  });
  final AuthService authService;
  final ValueChanged<AuthSession> onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  OtpChallenge? _challenge;
  Timer? _ticker;
  DateTime? _expiresAt, _resendAt;
  bool _loading = false, _mustResend = false;
  String? _error;
  String _requestedPhone = '';
  int _secondsUntil(DateTime? date) => date == null
      ? 0
      : math.max(
          0,
          (date.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
        );
  int get _resendSeconds => _secondsUntil(_resendAt);
  bool get _expired =>
      _mustResend || (_challenge != null && _secondsUntil(_expiresAt) == 0);
  String get _displayPhone => _requestedPhone.isEmpty
      ? ''
      : '+91 ${_requestedPhone.substring(3, 8)} ${_requestedPhone.substring(8)}';
  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_resendSeconds == 0 && (_challenge == null || _expired)) {
        _ticker?.cancel();
      }
    });
  }

  Future<void> _requestOtp({bool resend = false}) async {
    if (_loading || _resendSeconds > 0) return;
    if (!resend && !(_formKey.currentState?.validate() ?? false)) return;
    final phone = resend ? _requestedPhone : '+91${_phone.text.trim()}';
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenge = await widget.authService.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _requestedPhone = phone;
        _otp.clear();
        _mustResend = false;
        _expiresAt = DateTime.now().add(Duration(seconds: challenge.expiresIn));
        _resendAt = DateTime.now().add(Duration(seconds: challenge.retryAfter));
      });
      _startTicker();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        if (error.retryAfter != null) {
          _resendAt = DateTime.now().add(Duration(seconds: error.retryAfter!));
        }
      });
      if (error.retryAfter != null) _startTicker();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not start verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_loading || _challenge == null) return;
    if (_expired) {
      setState(
        () => _error = 'This code has expired. Please request a new code.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.authService.verifyOtp(
        _challenge!.id,
        _otp.text,
      );
      if (!mounted) return;
      _ticker?.cancel();
      widget.onAuthenticated(session);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _mustResend =
            error.code == 'attempt_limit' || error.code == 'challenge_expired';
        if (error.retryAfter != null) {
          _resendAt = DateTime.now().add(Duration(seconds: error.retryAfter!));
        }
      });
      _otp.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _otp.text.length,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not verify your code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeNumber() {
    if (_loading) return;
    _ticker?.cancel();
    setState(() {
      _challenge = null;
      _error = null;
      _mustResend = false;
      _otp.clear();
      _expiresAt = null;
      _resendAt = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _challenge == null && !_loading,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_loading) _changeNumber();
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          return Row(
            children: [
              if (wide)
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: const _BrandPanel(),
                    ),
                  ),
                ),
              Expanded(
                flex: wide ? 11 : 1,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, pane) => SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 48 : 24,
                        vertical: wide ? 36 : 28,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            pane.maxHeight - (wide ? 72 : 56),
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 424),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!wide) ...[
                                  const FacePayLogo(size: 38),
                                  const SizedBox(height: 42),
                                ],
                                _buildForm(),
                                const SizedBox(height: 34),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                    SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        'Your number. Your account.',
                                        style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _buildForm() {
    final verifying = _challenge != null;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'A LITTLE MORE HUMAN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  verifying ? '02 / 02' : '01 / 02',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            if (verifying) ...[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              verifying
                  ? 'One code.\nYou’re right here.'
                  : 'Good to see\nyou again.',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 39,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.7,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              verifying
                  ? 'Enter the 6-digit code for $_displayPhone.'
                  : 'Enter your mobile number. We’ll help you\nget back to the people who matter.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 30),
            if (!verifying) ...[
              const Text(
                'Mobile number',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('auth-phone'),
                controller: _phone,
                enabled: !_loading,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  hintText: '10-digit mobile number',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 12),
                        SizedBox(height: 22, child: VerticalDivider(width: 1)),
                      ],
                    ),
                  ),
                ),
                validator: (value) =>
                    RegExp(r'^[6-9][0-9]{9}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid 10-digit Indian mobile number.',
                onFieldSubmitted: (_) => _requestOtp(),
              ),
              const SizedBox(height: 12),
              const Text(
                'No password to remember. Just a verification code.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Verification code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _changeNumber,
                    child: const Text(
                      'Change number',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('auth-otp'),
                controller: _otp,
                enabled: !_loading,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 30,
                  letterSpacing: 14,
                  fontWeight: FontWeight.w800,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  hintText: '------',
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 30,
                    letterSpacing: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB5AFCE),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 21,
                  ),
                ),
                validator: (value) =>
                    RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                    ? null
                    : 'Enter all 6 digits of the verification code.',
                onFieldSubmitted: (_) => _verifyOtp(),
              ),
              const SizedBox(height: 12),
              Text(
                _expired
                    ? 'Code expired. Request a new one below.'
                    : 'Your code expires in ${_clock(_secondsUntil(_expiresAt))}',
                style: TextStyle(
                  fontSize: 11,
                  color: _expired ? AppColors.danger : AppColors.muted,
                ),
              ),
              if (_challenge!.developmentTest) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Test verification is ready. Use your configured test code. No SMS was sent.',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            PrimaryButton(
              label: _loading
                  ? (verifying ? 'Verifying…' : 'Please wait…')
                  : (verifying
                        ? 'Verify & continue'
                        : (_resendSeconds > 0
                              ? 'Try again in ${_clock(_resendSeconds)}'
                              : 'Continue')),
              loading: _loading,
              onPressed: verifying
                  ? (_expired ? null : _verifyOtp)
                  : (_resendSeconds > 0 ? null : () => _requestOtp()),
              icon: Icons.arrow_forward_rounded,
            ),
            if (verifying) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _loading || _resendSeconds > 0
                      ? null
                      : () => _requestOtp(resend: true),
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend in ${_clock(_resendSeconds)}'
                        : 'Resend code',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'A simpler hello. A little more you.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 800;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF171735), Color(0xFF25204E)],
            ),
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.all(compact ? 34 : 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FacePayLogo(size: 40, light: true),
                    SizedBox(height: compact ? 30 : 52),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFBDFAC8),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'PAYMENTS. WITH A PERSONAL TOUCH.',
                          style: TextStyle(
                            color: Color(0xFFCBC7E1),
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Text(
                      'Less friction.\nMore living.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 42 : 51,
                        height: 1.13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'A familiar face. A whole new way to pay.\n'
                      'Meet money that moves with you.',
                      style: TextStyle(
                        color: Color(0xFFAAA5C8),
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 20),
                    SizedBox(
                      height: compact ? 260 : 320,
                      width: double.infinity,
                      child: const _IdentityGraphic(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: const [
                        _FeatureChip(
                          icon: Icons.face_retouching_natural_rounded,
                          label: 'Made for you',
                        ),
                        _FeatureChip(
                          icon: Icons.bolt_rounded,
                          label: 'Move in a moment',
                        ),
                        _FeatureChip(
                          icon: Icons.tune_rounded,
                          label: 'You’re in control',
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 27 : 42),
                    const Text(
                      'A simple hello to the future of payments.',
                      style: TextStyle(color: Color(0xFF8F8AAE), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFB7ADFA), size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD4CFE6), fontSize: 9),
        ),
      ],
    ),
  );
}

class _IdentityGraphic extends StatelessWidget {
  const _IdentityGraphic();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dimension = math.min(constraints.maxWidth, constraints.maxHeight);
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _OrbitPainter(),
          ),
          Transform.rotate(
            angle: -0.09,
            child: Container(
              width: dimension * 0.57,
              height: dimension * 0.68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8065DB), Color(0xFF5841A8)],
                ),
                borderRadius: BorderRadius.circular(29),
                border: Border.all(
                  color: const Color(0xFFC8B9FF).withValues(alpha: 0.5),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x336C4CEC),
                    blurRadius: 55,
                    spreadRadius: 15,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: Size(dimension * 0.32, dimension * 0.34),
                    painter: _FacePainter(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'UNIQUELY YOU',
                    style: TextStyle(
                      color: Color(0xFFEAE3FF),
                      fontSize: 8,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: constraints.maxHeight * 0.20,
            child: Transform.rotate(
              angle: 0.045,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F5FF),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 24),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFE7DCF9),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFF7653D2),
                        size: 15,
                      ),
                    ),
                    SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coffee with Maya',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF262039),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Little moments, made easy',
                          style: TextStyle(
                            fontSize: 8,
                            color: Color(0xFF827890),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: constraints.maxHeight * 0.15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFC3F1CB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF345F42),
                    size: 19,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'A smile. And you’re on your way.',
                    style: TextStyle(
                      color: Color(0xFF345F42),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dimension = math.min(size.width, size.height);
    final paint = Paint()
      ..color = const Color(0xFF8876C0).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, dimension * 0.43, paint);
    canvas.drawCircle(center, dimension * 0.56, paint);
    canvas.drawCircle(
      center.translate(-dimension * 0.40, -dimension * 0.15),
      5,
      Paint()..color = const Color(0xFFAA94F2),
    );
    canvas.drawCircle(
      center.translate(dimension * 0.38, dimension * 0.24),
      4,
      Paint()..color = const Color(0xFFD5FAD8),
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.08 + i * 9, size.height * 0.18),
        1,
        Paint()..color = const Color(0xFF81719C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0E8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    const corner = 0.18;
    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        canvas.save();
        canvas.translate(flipX ? w : 0, flipY ? h : 0);
        canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
        canvas.drawPath(
          Path()
            ..moveTo(0, h * corner)
            ..lineTo(0, h * 0.07)
            ..quadraticBezierTo(0, 0, w * 0.07, 0)
            ..lineTo(w * corner, 0),
          paint,
        );
        canvas.restore();
      }
    }
    canvas.drawLine(
      Offset(w * 0.30, h * 0.33),
      Offset(w * 0.30, h * 0.43),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.70, h * 0.33),
      Offset(w * 0.70, h * 0.43),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.51, h * 0.35)
        ..lineTo(w * 0.51, h * 0.55)
        ..quadraticBezierTo(w * 0.50, h * 0.59, w * 0.45, h * 0.57),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.29, h * 0.68)
        ..quadraticBezierTo(w * 0.5, h * 0.85, w * 0.71, h * 0.68),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
