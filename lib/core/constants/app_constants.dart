/// Application and protocol-wide constants for Munchkin Offline Companion.
library;
abstract final class AppConstants {
  static const String appMarker = 'mksync';
  static const int protocolVersion = 1;
  static const int defaultPort = 8787;

  // Level limits
  static const int minLevel = 1;
  static const int defaultMaxLevel = 20;
  static const int absoluteMaxLevel = 22;

  // Gear limits
  static const int minGearPower = 0;
  static const int maxGearPower = 999;

  // Player name constraints
  static const int minNameLength = 1;
  static const int maxNameLength = 24;

  // Timing and timeouts (Duration)
  static const Duration connectTimeout = Duration(seconds: 2);
  static const Duration requestExpiry = Duration(seconds: 60);
  static const Duration pingInterval = Duration(seconds: 8);
  static const Duration clientWatchdogTimeout = Duration(seconds: 20);
  static const Duration hostWatchdogTimeout = Duration(seconds: 25);
  static const Duration seatGracePeriod = Duration(minutes: 5);
  static const Duration snapshotDebounce = Duration(milliseconds: 500);

  // Search
  static const int maxEntitySearchResults = 8;
  static const int maxTextSearchResults = 30;
  static const Duration searchDebounce = Duration(milliseconds: 200);
}
