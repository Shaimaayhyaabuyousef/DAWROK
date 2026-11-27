import 'package:flutter/foundation.dart';

/// Temporary diagnostic version of Dawrok's citizen preferences.
///
/// It deliberately avoids shared_preferences and all platform plugins.
/// Settings stay available while the app is running, but are NOT persisted
/// across full app restarts. Never put secrets, national IDs or PINs here.
///
/// This preserves the existing API used by ProfileScreen and
/// CitizenSettingsScreen, so no screen needs to change for this test.
class CitizenPreferences {
  CitizenPreferences._();

  static final CitizenPreferences instance = CitizenPreferences._();

  final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);
  final ValueNotifier<bool> saveImages = ValueNotifier<bool>(false);
  final ValueNotifier<bool> smsAlerts = ValueNotifier<bool>(false);

  /// No-op: no plugin is initialized and no stored values are read.
  Future<void> load() async {}

  Future<void> setDarkMode(bool value) async {
    darkMode.value = value;
  }

  Future<void> setSaveImages(bool value) async {
    saveImages.value = value;
  }

  Future<void> setSmsAlerts(bool value) async {
    smsAlerts.value = value;
  }
}
