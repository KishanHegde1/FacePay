import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/device_lock_service.dart';
import '../ui/design.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.deviceLockService,
  });
  final AppSettings settings;
  final DeviceLockService? deviceLockService;

  Future<void> _setTheme(BuildContext context, ThemeMode mode) async {
    try {
      await settings.setThemeMode(mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appearance could not be saved. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Settings')),
    body: AnimatedBuilder(
      animation: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Make FacePay yours',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Choose an appearance that feels right.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 24),
                  _AppLockSetting(
                    settings: settings,
                    service: deviceLockService,
                  ),
                  SizedBox(height: 24),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'System follows your phone’s light or dark setting.',
                        ),
                        SizedBox(height: 16),
                        for (final mode in ThemeMode.values)
                          ListTile(
                            key: ValueKey('theme-${mode.name}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(switch (mode) {
                              ThemeMode.system =>
                                Icons.brightness_auto_outlined,
                              ThemeMode.light => Icons.light_mode_outlined,
                              ThemeMode.dark => Icons.dark_mode_outlined,
                            }),
                            title: Text(switch (mode) {
                              ThemeMode.system => 'System',
                              ThemeMode.light => 'Light',
                              ThemeMode.dark => 'Dark',
                            }),
                            trailing: settings.themeMode == mode
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : Icon(Icons.radio_button_unchecked_rounded),
                            selected: settings.themeMode == mode,
                            enabled: !settings.saving,
                            onTap: () => _setTheme(context, mode),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About FacePay',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 12),
                        const FacePayLogo(size: 36),
                        SizedBox(height: 12),
                        Text('Payments, with a smile.'),
                        SizedBox(height: 6),
                        Text('More settings will be added in future updates.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AppLockSetting extends StatefulWidget {
  const _AppLockSetting({required this.settings, this.service});

  final AppSettings settings;
  final DeviceLockService? service;

  @override
  State<_AppLockSetting> createState() => _AppLockSettingState();
}

class _AppLockSettingState extends State<_AppLockSetting> {
  late final DeviceLockService _service =
      widget.service ?? LocalDeviceLockService();
  bool _checking = false;

  Future<void> _changed(bool enabled) async {
    if (_checking || widget.settings.saving) return;
    setState(() => _checking = true);
    try {
      if (enabled && !await _service.hasEnrolledBiometrics()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Add a fingerprint or face in your phone lock settings first.',
              ),
            ),
          );
        }
        return;
      }
      await widget.settings.setAppLockEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App lock could not be saved. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Lock FacePay when you leave the app. Authentication stays inside your phone.',
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('app-lock-switch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.fingerprint_rounded),
          title: const Text('Fingerprint or device face'),
          subtitle: Text(
            widget.settings.appLockEnabled
                ? 'App lock is on'
                : 'Use biometrics already registered on this phone',
          ),
          value: widget.settings.appLockEnabled,
          onChanged: _checking || widget.settings.saving ? null : _changed,
        ),
      ],
    ),
  );
}
