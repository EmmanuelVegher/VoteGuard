import 'package:ntp/ntp.dart';
import 'package:flutter/foundation.dart';

class TimeService {
  Future<DateTime> getWATTime() async {
    try {
      // Use pool.ntp.org for reliable time sync
      // The ntp package fetches the current network time from an NTP server.
      DateTime ntpTime = await NTP.now().timeout(const Duration(seconds: 4));
      // West Africa Time (WAT) is UTC+1
      return ntpTime.toUtc().add(const Duration(hours: 1));
    } catch (e) {
      debugPrint("NTP Sync Error: $e. Falling back to device time.");
    }
    // Fallback: Return current device time (ensuring it's treated as WAT for logic)
    return DateTime.now().toUtc().add(const Duration(hours: 1));
  }
}
