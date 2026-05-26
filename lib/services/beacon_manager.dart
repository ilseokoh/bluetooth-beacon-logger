import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/beacon_device.dart';
import '../models/beacon_parser.dart';

class BeaconManager extends ChangeNotifier {
  // Discovered iBeacon devices mapped by their unique key (uuid_major_minor)
  final Map<String, BeaconDevice> _devices = {};
  
  // List of devices to expose to the UI, sorted by UUID (ascending) for stable positioning
  List<BeaconDevice> get devices {
    final list = _devices.values.toList();
    list.sort((a, b) {
      final uuidComp = a.uuid.toLowerCase().compareTo(b.uuid.toLowerCase());
      if (uuidComp != 0) return uuidComp;
      
      final majorComp = a.major.compareTo(b.major);
      if (majorComp != 0) return majorComp;
      
      return a.minor.compareTo(b.minor);
    });
    return list;
  }

  // Active BLE scanning subscription
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  // 1.1s cycle pruning timer
  Timer? _pruningTimer;
  
  // Is the manager actively scanning
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Cached path to the base directory for file storage
  Directory? _baseDir;

  BeaconManager() {
    _initStorage();
    _initForegroundTask();
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'beacon_logging_channel',
        channelName: 'Beacon Logging Service',
        channelDescription: 'Keeps BLE scanning and logging active in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _initStorage() async {
    _baseDir = await _getBaseDirectory();
  }

  Future<Directory> _getBaseDirectory() async {
    if (Platform.isAndroid) {
      try {
        final extDirs = await getExternalStorageDirectory();
        if (extDirs != null) {
          return extDirs;
        }
      } catch (e) {
        debugPrint("Error getting external storage directories: $e");
      }
    }
    // Fallback for non-Android platforms or if external storage is unavailable
    return await getApplicationDocumentsDirectory();
  }

  /// Starts scanning for iBeacon devices.
  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    // Ensure Bluetooth is enabled before starting scan
    if (await FlutterBluePlus.isSupported == false) {
      _isScanning = false;
      notifyListeners();
      return;
    }

    // 1. Start periodic pruning timer (1.1s)
    _pruningTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      _pruneDevices();
    });

    // 2. Start continuous scanning using flutter_blue_plus
    // We scan continuously in the background/foreground stream.
    try {
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: true,
        continuousUpdates: true,
      );
    } catch (e) {
      debugPrint("Error starting BLE scan: $e");
    }

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final parsed = BeaconParser.parse(result);
        if (parsed != null) {
          _handleDiscoveredBeacon(parsed);
        }
      }
    });
  }

  /// Stops scanning for iBeacon devices.
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _isScanning = false;
    
    _pruningTimer?.cancel();
    _pruningTimer = null;

    _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Error stopping BLE scan: $e");
    }

    notifyListeners();
  }

  /// Processes a discovered iBeacon device.
  void _handleDiscoveredBeacon(BeaconDevice parsed) {
    final key = parsed.key;

    if (_devices.containsKey(key)) {
      final existing = _devices[key]!;
      
      // Update RSSI and handle UI throttling
      existing.updateRssi(parsed.rssi);
      
      // Reset missed cycles since we saw it in this cycle
      existing.missedCycles = 0;

      // If logging is active, append raw packet data to CSV file
      if (existing.isLogging) {
        _logPacketToFile(existing);
      }
    } else {
      // New device found
      _devices[key] = parsed;
    }
    notifyListeners();
  }

  /// Prunes devices that haven't received advertisement packets for 10 consecutive cycles.
  void _pruneDevices() {
    final keysToRemove = <String>[];
    
    _devices.forEach((key, device) {
      // Increment missed cycles for all devices
      device.missedCycles++;
      
      // If we missed 10 cycles (each cycle is 1.1s, so ~11 seconds), mark for removal
      // BUT: do not prune devices that are actively logging!
      if (device.missedCycles >= 10 && !device.isLogging) {
        keysToRemove.add(key);
      }
    });

    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        _devices.remove(key);
      }
      notifyListeners();
    }
  }

  /// Requests the necessary permissions for background service and BLE scanning.
  Future<bool> requestBackgroundPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 2. Request fine location permission (needed for scanning)
    final locStatus = await Permission.locationWhenInUse.request();
    if (!locStatus.isGranted) {
      return false;
    }

    // 3. Request background location permission (needed for background scanning on Android 10+)
    if (await Permission.locationAlways.isDenied) {
      final bgLocStatus = await Permission.locationAlways.request();
      if (!bgLocStatus.isGranted) {
        debugPrint("Background location permission denied.");
      }
    }

    // 4. Request ignoring battery optimizations
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  /// Starts or stops the foreground service depending on whether any device is logging.
  Future<void> _updateForegroundServiceState() async {
    if (!Platform.isAndroid) return;

    final activeLoggingDevices = _devices.values.where((d) => d.isLogging).toList();

    if (activeLoggingDevices.isNotEmpty) {
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Beacon 로깅 중',
          notificationText: '${activeLoggingDevices.length}개의 기기 데이터를 백그라운드에서 기록하고 있습니다.',
          callback: startCallback,
        );
      } else {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Beacon 로깅 중',
          notificationText: '${activeLoggingDevices.length}개의 기기 데이터를 백그라운드에서 기록하고 있습니다.',
        );
      }
    } else {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    }
  }

  /// Starts logging to CSV for a specific device.
  Future<void> startLogging(BeaconDevice device) async {
    if (device.isLogging) return;

    // Request permissions for background operations
    await requestBackgroundPermissions();

    _baseDir ??= await _getBaseDirectory();

    // 1. Create directory named after the device's UUID
    // Ensure lowercase UUID folder for consistent directory structures
    final deviceDir = Directory('${_baseDir!.path}/${device.uuid.toLowerCase()}');
    if (!await deviceDir.exists()) {
      await deviceDir.create(recursive: true);
    }

    // 2. Generate filename: yyyy-MM-dd_HH-mm-ss.csv (using safe hyphens)
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final filePath = '${deviceDir.path}/$formattedDate.csv';

    device.isLogging = true;
    device.activeLogFilePath = filePath;
    device.packetCount = 0;

    // 3. Create file and write CSV header
    final file = File(filePath);
    await file.writeAsString('timestamp,txpower,rssi\n', mode: FileMode.write);

    // Update foreground service state
    await _updateForegroundServiceState();

    notifyListeners();
  }

  /// Stops logging to CSV for a specific device.
  Future<void> stopLogging(BeaconDevice device) async {
    if (!device.isLogging) return;

    device.isLogging = false;
    device.activeLogFilePath = null;

    // Update foreground service state
    await _updateForegroundServiceState();

    notifyListeners();
  }

  /// Logs a raw advertisement packet to the active CSV file.
  Future<void> _logPacketToFile(BeaconDevice device) async {
    final filePath = device.activeLogFilePath;
    if (filePath == null) return;

    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    
    // csv format: timestamp,txpower,rssi
    final csvLine = '$timestamp,${device.txPower},${device.rssi}\n';

    try {
      final file = File(filePath);
      await file.writeAsString(csvLine, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint("Error writing packet to CSV: $e");
    }
  }

  /// Fetches the latest 50 logs from the active session or the latest saved CSV file if stopped.
  Future<List<String>> getTerminalLogs(BeaconDevice device) async {
    // If actively logging, return the active in-memory/on-disk log entries
    if (device.isLogging && device.activeLogFilePath != null) {
      try {
        final file = File(device.activeLogFilePath!);
        if (await file.exists()) {
          final lines = await file.readAsLines();
          if (lines.length > 1) {
            // Remove header row
            final dataLines = lines.sublist(1);
            // Convert csv format to premium readable format: "2026-05-25 06:55:14.469, FDA50693, 1001, 4502, -53, -12"
            return dataLines.map((line) {
              final parts = line.split(',');
              if (parts.length >= 3) {
                final ts = parts[0];
                final tx = parts[1];
                final rs = parts[2];
                final shortUuid = device.uuid.substring(0, 8).toUpperCase();
                return '$ts, $shortUuid, ${device.major}, ${device.minor}, $rs, $tx';
              }
              return line;
            }).toList();
          }
        }
      } catch (e) {
        debugPrint("Error reading active log file: $e");
      }
      return [];
    }

    // If stopped, load from the most recent CSV file under the uuid folder
    _baseDir ??= await _getBaseDirectory();
    
    final deviceDir = Directory('${_baseDir!.path}/${device.uuid.toLowerCase()}');
    if (!await deviceDir.exists()) {
      return ['[SYSTEM] No logs captured yet.'];
    }

    try {
      final files = deviceDir.listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList();

      if (files.isEmpty) {
        return ['[SYSTEM] No log files found.'];
      }

      // Sort files by path (which is date-formatted) descending to get the latest
      files.sort((a, b) => b.path.compareTo(a.path));
      final latestFile = files.first;

      final lines = await latestFile.readAsLines();
      if (lines.length <= 1) {
        return ['[SYSTEM] Log file is empty.'];
      }

      final dataLines = lines.sublist(1); // Remove header
      return dataLines.map((line) {
        final parts = line.split(',');
        if (parts.length >= 3) {
          final ts = parts[0];
          final tx = parts[1];
          final rs = parts[2];
          final shortUuid = device.uuid.substring(0, 8).toUpperCase();
          return '$ts, $shortUuid, ${device.major}, ${device.minor}, $rs, $tx';
        }
        return line;
      }).toList();
    } catch (e) {
      debugPrint("Error reading historical logs: $e");
      return ['[SYSTEM] Error reading log files: $e'];
    }
  }

  @override
  void dispose() {
    stopScanning();
    super.dispose();
  }
}

// The callback function must be top-level or static
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LoggingTaskHandler());
}

class LoggingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
