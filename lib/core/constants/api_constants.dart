class ApiConstants {
  // For Android emulator use 10.0.2.2 to reach the host machine.
  static const String host = 'http://10.0.2.2:8000';

  // Base URL for API endpoints (used by Dio baseUrl).
  static const String baseUrl = '$host/api/';
}
