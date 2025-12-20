import 'package:package_info_plus/package_info_plus.dart';

/// Utility class to get app information
class AppInfo {
  static PackageInfo? _packageInfo;

  /// Initialize app info (call this once at app startup)
  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get app name
  static String get appName => _packageInfo?.appName ?? 'Elysian';

  /// Get app version
  static String get version => _packageInfo?.version ?? '0.0.1';

  /// Get build number
  static String get buildNumber => _packageInfo?.buildNumber ?? '1';

  /// Get full version string (e.g., "1.0.0 (1)")
  static String get fullVersion => '$version ($buildNumber)';

  /// Get package name
  static String get packageName =>
      _packageInfo?.packageName ?? 'com.kingrittik.elysian';
}
