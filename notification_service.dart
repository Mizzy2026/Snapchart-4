/// Simple notification stub for first successful build.
class NotificationService {
  bool notifyAll = true;
  int minQuality = 70;
  Set<String> allowedPairs = {'EURUSD', 'GBPUSD', 'USDJPY'};

  Future<void> init() async {
    // No-op for first APK
  }

  Future<void> showSetupAlert({
    required String pair,
    required String direction,
    required int quality,
  }) async {
    // Placeholder
  }
}
