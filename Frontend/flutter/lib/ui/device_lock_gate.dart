import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_lock_service.dart';
import 'design.dart';

class DeviceLockGate extends StatefulWidget {
  const DeviceLockGate({
    super.key,
    required this.active,
    required this.enabled,
    required this.service,
    required this.child,
    required this.onUseAnotherAccount,
  });

  final bool active;
  final bool enabled;
  final DeviceLockService service;
  final Widget child;
  final Future<void> Function() onUseAnotherAccount;

  @override
  State<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends State<DeviceLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  String? _message;

  bool get _required => widget.active && widget.enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = _required;
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void didUpdateWidget(covariant DeviceLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_required) {
      if (_locked || _message != null) {
        setState(() {
          _locked = false;
          _message = null;
        });
      }
      return;
    }
    if (!oldWidget.active && widget.active && widget.enabled && !_locked) {
      setState(() => _locked = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_required) return;
    if (state == AppLifecycleState.paused && !_authenticating) {
      if (mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      unawaited(_unlock());
    }
  }

  Future<void> _unlock() async {
    if (!mounted || !_required || !_locked || _authenticating) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final unlocked = await widget.service.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !unlocked;
      if (!unlocked) {
        _message = 'FacePay is locked. Use your phone screen lock to continue.';
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.service.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_required || !_locked) return widget.child;
    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: AppPalette.of(context).background,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FacePayLogo(size: 54),
                    const SizedBox(height: 42),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppPalette.of(context).primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phonelink_lock_rounded,
                        size: 50,
                        color: AppPalette.of(context).primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'FacePay is locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.of(context).ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _message ??
                          'Use your phone’s fingerprint, face, PIN, pattern, or password to unlock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.of(context).muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: _authenticating ? 'Checking…' : 'Unlock FacePay',
                      icon: Icons.lock_open_rounded,
                      onPressed: _authenticating ? null : _unlock,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _authenticating
                          ? null
                          : widget.onUseAnotherAccount,
                      child: const Text('Sign in with another account'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'FacePay receives only an unlock result. Your fingerprint, face, PIN, pattern, and password stay inside the phone’s secure system.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.of(context).muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
