import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_lock_service.dart';

class DeviceLockGate extends StatefulWidget {
  const DeviceLockGate({
    super.key,
    required this.active,
    required this.enabled,
    required this.service,
    required this.child,
  });

  final bool active;
  final bool enabled;
  final DeviceLockService service;
  final Widget child;

  @override
  State<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends State<DeviceLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;

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
      if (_locked) setState(() => _locked = false);
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
    setState(() => _authenticating = true);
    final unlocked = await widget.service.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !unlocked;
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _authenticating ? null : _unlock,
        child: const ColoredBox(
          key: ValueKey('device-lock-blank-screen'),
          color: Colors.white,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
