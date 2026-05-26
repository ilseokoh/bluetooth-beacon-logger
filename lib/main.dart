import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/beacon_manager.dart';
import 'screens/device_list_screen.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  // Set flutter_blue_plus log level (optional, but good for debugging)
  FlutterBluePlus.setLogLevel(LogLevel.none);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BeaconManager _beaconManager = BeaconManager();

  @override
  void dispose() {
    _beaconManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Beacon Logger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BluetoothAdapterStateObserver(
        beaconManager: _beaconManager,
      ),
    );
  }
}

/// An observer widget that checks if Bluetooth is supported and enabled on the device.
/// Shows a premium warning screen if Bluetooth is off, or redirects to the main DeviceListScreen.
class BluetoothAdapterStateObserver extends StatelessWidget {
  final BeaconManager beaconManager;

  const BluetoothAdapterStateObserver({
    super.key,
    required this.beaconManager,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothAdapterState>(
      stream: FlutterBluePlus.adapterState,
      initialData: BluetoothAdapterState.unknown,
      builder: (context, snapshot) {
        final state = snapshot.data;
        
        if (state == BluetoothAdapterState.on) {
          // Bluetooth is on! Show the main device list screen
          return DeviceListScreen(beaconManager: beaconManager);
        }
        
        // Otherwise, show a premium warning/onboarding screen
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bluetooth Icon with premium styling
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '블루투스가 꺼져 있습니다',
                    style: AppTheme.headlineMd(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bluetooth Beacon 신호를 스캔하고 실시간으로 로깅하기 위해서는 기기의 블루투스 및 위치 권한 활성화가 필요합니다.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd(context).copyWith(
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action button to prompt enabling bluetooth (on Android)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FlutterBluePlus.turnOn();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('블루투스를 켤 수 없습니다: $e'),
                              backgroundColor: AppColors.secondaryContainer,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_rounded),
                          SizedBox(width: 8),
                          Text(
                            '블루투스 켜기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
