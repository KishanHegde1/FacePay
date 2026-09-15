import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/scanner_session.dart';
import '../ui/design.dart';
import 'scan_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.state, this.session});

  final AppState state;

  /// Optional injected session for device-independent UI checks.
  final ScannerSession? session;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final ScannerSession _session;
  bool _showingResult = false;
  bool _active = true;
  bool _resumeScanning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.session ?? MlKitScannerSession();
    _session.addListener(_changed);
    unawaited(_session.start());
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_session.status == ScannerStatus.detected &&
        !_showingResult &&
        _active &&
        _resumeScanning) {
      _showingResult = true;
      _resumeScanning = false;
      unawaited(_openResult());
    }
  }

  Future<void> _openResult() async {
    final detection = _session.detection!;
    await _session.stop();
    if (!mounted) return;
    if (!_active) {
      setState(() => _showingResult = false);
      return;
    }
    final scanAgain = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ScanResultScreen(state: widget.state, detection: detection),
      ),
    );
    if (!mounted) return;
    setState(() => _showingResult = false);
    // Back leaves the camera paused. Only an explicit scan-again action
    // rearms detection, so an unchanged QR/face cannot loop through routes.
    if (scanAgain == true && _active) _start();
  }

  void _start() {
    _resumeScanning = true;
    unawaited(_session.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      unawaited(_session.stop());
    } else if (!_showingResult &&
        _resumeScanning &&
        _session.status != ScannerStatus.error &&
        _session.status != ScannerStatus.unsupported) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _session.status;
    final scanning = status == ScannerStatus.scanning;
    final error = status == ScannerStatus.error;
    final unsupported = status == ScannerStatus.unsupported;
    return Scaffold(
      backgroundColor: const Color(0xFF17162B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17162B),
        foregroundColor: Colors.white,
        title: Text(_session.checkingBlinks ? 'Blink check' : 'Scan & pay'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  _session.checkingBlinks ? 'Blink twice' : 'Scan QR or face',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: (MediaQuery.sizeOf(context).height * .45).clamp(
                      220.0,
                      420.0,
                    ),
                    child: ColoredBox(
                      color: const Color(0xFF292541),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(child: _session.buildPreview()),
                          if (status == ScannerStatus.starting)
                            const CircularProgressIndicator(
                              color: AppColors.mint,
                            ),
                          if (scanning)
                            IgnorePointer(
                              child: FractionallySizedBox(
                                widthFactor: .78,
                                heightFactor: .64,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      _session.checkingBlinks ? 90 : 20,
                                    ),
                                    border: Border.all(
                                      color: AppColors.mint,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_session.checkingBlinks && scanning) ...[
                  Text(
                    '${_session.blinkCount} / 2 blinks',
                    key: const ValueKey('blink-progress'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Screen/device check active. Remove any phone, tablet, photo, or display from view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD0CAE4),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _resumeScanning
                      ? _session.message
                      : 'Scanner paused. Tap Scan again to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD0CAE4), height: 1.6),
                ),
                const SizedBox(height: 20),
                if (!unsupported &&
                    (error ||
                        status == ScannerStatus.idle ||
                        status == ScannerStatus.detected))
                  PrimaryButton(
                    label: error ? 'Try again' : 'Scan again',
                    onPressed: _start,
                    icon: Icons.refresh_rounded,
                  ),
                if (scanning)
                  TextButton.icon(
                    onPressed: () => unawaited(_session.switchCamera()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mint,
                    ),
                    icon: const Icon(Icons.flip_camera_android_outlined),
                    label: const Text('Switch camera'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Images stay on this device. The device/screen check is a warning only; face recognition and payment authorization are separate steps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB8B3CB),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
