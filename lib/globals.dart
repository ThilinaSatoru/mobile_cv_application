class ServerConfig {
  static const String serverIp = '10.0.2.2';
  static const int serverPort = 8000;
  static const int timeoutSeconds = 30;
  static const String serverUrl =
      '${ServerConfig.serverIp}:${ServerConfig.serverPort}';
}
