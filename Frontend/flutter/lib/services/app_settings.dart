import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  bool _appLockEnabled = false;
  bool get appLockEnabled => _appLockEnabled;
  bool _loaded = false;
  bool get loaded => _loaded;
  int _revision = 0;
  bool _saving = false;
  bool _disposed = false;
  bool get saving => _saving;
  static const themeKey = 'facepay.appearance';
  static const appLockKey = 'facepay.app-lock';

  Future<void> load() async {
    final revision = _revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(themeKey);
      if (_disposed) return;
      if (revision != _revision) {
        _loaded = true;
        notifyListeners();
        return;
      }
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.system,
      );
      _appLockEnabled = preferences.getBool(appLockKey) ?? false;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // An unreadable preference keeps the safe system default.
      if (!_disposed) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    if (_disposed || _saving || enabled == _appLockEnabled) return;
    _saving = true;
    _revision++;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(appLockKey, enabled)) {
        throw StateError('Could not save app lock');
      }
      _appLockEnabled = enabled;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_disposed || _saving || mode == _themeMode) return;
    _saving = true;
    _revision++;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString(themeKey, mode.name)) {
        throw StateError('Could not save appearance');
      }
      _themeMode = mode;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;
}
