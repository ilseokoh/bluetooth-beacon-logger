class BeaconDevice {
  final String uuid;
  final String mac;
  final int major;
  final int minor;
  final int txPower;
  
  // Real-time values
  int rssi;
  int displayedRssi;
  int missedCycles;
  
  // Logging state
  bool isLogging;
  String? activeLogFilePath;
  int packetCount;
  final List<String> miniTerminalLogs;

  BeaconDevice({
    required this.uuid,
    required this.mac,
    required this.major,
    required this.minor,
    required this.txPower,
    required this.rssi,
    this.missedCycles = 0,
    this.isLogging = false,
    this.activeLogFilePath,
    this.packetCount = 0,
    List<String>? miniTerminalLogs,
  })  : displayedRssi = rssi,
        miniTerminalLogs = miniTerminalLogs ?? [];

  /// Unique key to identify a beacon.
  /// Typically, an iBeacon is identified by UUID + Major + Minor.
  String get key => '${uuid.toLowerCase()}_${major}_$minor';

  /// Updates the RSSI and displayed RSSI based on the 10-packet rule.
  /// If logging is in progress, the displayed RSSI is updated only once every 10 packets.
  /// If not logging, it updates in real-time.
  void updateRssi(int newRssi) {
    rssi = newRssi;
    if (!isLogging) {
      displayedRssi = newRssi;
    } else {
      packetCount++;
      if (packetCount % 10 == 0) {
        displayedRssi = newRssi;
      }
    }
  }

  /// Adds a log message to the mini-terminal, keeping only the last 10 messages.
  void addMiniLog(String message) {
    miniTerminalLogs.add(message);
    if (miniTerminalLogs.length > 10) {
      miniTerminalLogs.removeAt(0);
    }
  }

  /// Creates a copy of this device with some updated fields.
  BeaconDevice copyWith({
    String? uuid,
    String? mac,
    int? major,
    int? minor,
    int? txPower,
    int? rssi,
    int? displayedRssi,
    int? missedCycles,
    bool? isLogging,
    String? activeLogFilePath,
    int? packetCount,
    List<String>? miniTerminalLogs,
  }) {
    final copy = BeaconDevice(
      uuid: uuid ?? this.uuid,
      mac: mac ?? this.mac,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      txPower: txPower ?? this.txPower,
      rssi: rssi ?? this.rssi,
      missedCycles: missedCycles ?? this.missedCycles,
      isLogging: isLogging ?? this.isLogging,
      activeLogFilePath: activeLogFilePath ?? this.activeLogFilePath,
      packetCount: packetCount ?? this.packetCount,
      miniTerminalLogs: miniTerminalLogs != null ? List.from(miniTerminalLogs) : List.from(this.miniTerminalLogs),
    );
    if (displayedRssi != null) {
      copy.displayedRssi = displayedRssi;
    } else if (rssi != null && !(isLogging ?? this.isLogging)) {
      copy.displayedRssi = rssi;
    } else {
      copy.displayedRssi = this.displayedRssi;
    }
    return copy;
  }
}
