import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  int _revision = 0;
  bool _saving = false;
  bool _disposed = false;
  bool get saving => _saving;
  static const themeKey = 'facepay.appearance';

  Future<void> load() async {
    final revision = _revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(themeKey);
      if (_disposed || revision != _revision) return;
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (_) {
      // An unreadable preference keeps the safe system default.
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
