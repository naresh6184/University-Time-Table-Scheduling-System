import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefKey = 'theme_mode_preference';

  @override
  ThemeMode build() {
    _loadPreference();
    return ThemeMode.light; // Default to light mode for corporate look
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefKey);
    if (savedMode != null) {
      if (savedMode == 'light') {
        state = ThemeMode.light;
      } else if (savedMode == 'dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }

  Future<void> toggleMode() async {
    if (state == ThemeMode.light) {
      await setMode(ThemeMode.dark);
    } else {
      await setMode(ThemeMode.light);
    }
  }
}
