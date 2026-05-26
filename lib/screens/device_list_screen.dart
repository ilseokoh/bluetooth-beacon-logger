import 'package:flutter/material.dart';
import '../models/beacon_device.dart';
import '../services/beacon_manager.dart';
import '../theme/theme.dart';
import 'device_detail_screen.dart';

class DeviceListScreen extends StatefulWidget {
  final BeaconManager beaconManager;

  const DeviceListScreen({super.key, required this.beaconManager});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-start scanning when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.beaconManager.startScanning();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '기기 리스트',
          style: AppTheme.headlineMd(context).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Scan state indicator and manual start/stop button
          ListenableBuilder(
            listenable: widget.beaconManager,
            builder: (context, _) {
              final isScanning = widget.beaconManager.isScanning;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    if (isScanning) ...[
                      const _ScanningIndicator(),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: Icon(
                        isScanning ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      onPressed: () {
                        if (isScanning) {
                          widget.beaconManager.stopScanning();
                        } else {
                          widget.beaconManager.startScanning();
                        }
                      },
                      tooltip: isScanning ? '스캔 중지' : '스캔 시작',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.beaconManager,
        builder: (context, _) {
          final devices = widget.beaconManager.devices;

          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bluetooth_searching_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '주변의 iBeacon 기기를 검색 중입니다...',
                    style: AppTheme.bodyLg(context).copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '기기가 iBeacon 규격인지 확인해 주세요.',
                    style: AppTheme.bodyMd(context).copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _DeviceCard(
                  device: device,
                  beaconManager: widget.beaconManager,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A custom scanning visual indicator (pulsing ring/dots)
class _ScanningIndicator extends StatefulWidget {
  const _ScanningIndicator();

  @override
  State<_ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<_ScanningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        Icons.sync_rounded,
        color: AppColors.primary,
        size: 20,
      ),
    );
  }
}

/// Pulsing REC Dot Widget for recording/logging states
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.secondaryContainer, // Vibrant red
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Individual device card component
class _DeviceCard extends StatelessWidget {
  final BeaconDevice device;
  final BeaconManager beaconManager;

  const _DeviceCard({
    required this.device,
    required this.beaconManager,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLogging = device.isLogging;

    // Define signal icon and colors based on RSSI strength
    IconData signalIcon;
    Color signalColor;
    if (device.rssi >= -65) {
      signalIcon = Icons.signal_cellular_alt_rounded;
      signalColor = AppColors.signalGreen;
    } else if (device.rssi >= -80) {
      signalIcon = Icons.signal_cellular_alt_2_bar_rounded;
      signalColor = AppColors.primary;
    } else {
      signalIcon = Icons.signal_cellular_alt_1_bar_rounded;
      signalColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(
              device: device,
              beaconManager: beaconManager,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLogging ? AppColors.primary.withValues(alpha: 0.5) : AppColors.outlineVariant,
            width: isLogging ? 1.5 : 1.0,
          ),
          boxShadow: isLogging
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // UUID & RSSI Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UUID section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UUID',
                              style: AppTheme.labelCaps(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              device.uuid,
                              style: AppTheme.dataMono(context, size: 14),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // RSSI Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // If logging, show pulsing LOGGING indicator, else standard layout
                          if (isLogging) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PulsingDot(),
                                const SizedBox(width: 6),
                                Text(
                                  'LOGGING',
                                  style: AppTheme.labelCaps(context).copyWith(
                                    color: AppColors.secondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                signalIcon,
                                color: signalColor,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${device.displayedRssi} dBm',
                                style: AppTheme.dataMono(context,
                                    color: signalColor, size: 18).copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RSSI STRENGTH',
                            style: AppTheme.labelCaps(context).copyWith(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Embedded Data Container (MAC & iBeacon details grid)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // MAC row
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                'MAC',
                                style: AppTheme.labelCaps(context).copyWith(fontSize: 10),
                              ),
                            ),
                            Text(
                              device.mac,
                              style: AppTheme.dataMono(context, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.outlineVariant, height: 1, thickness: 0.5),
                        const SizedBox(height: 8),
                        
                        // Major / Minor / TxPower row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text('MAJOR', style: AppTheme.labelCaps(context).copyWith(fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${device.major}',
                                    style: AppTheme.dataMono(context, color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('MINOR', style: AppTheme.labelCaps(context).copyWith(fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${device.minor}',
                                    style: AppTheme.dataMono(context, color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 28, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('TX POWER', style: AppTheme.labelCaps(context).copyWith(fontSize: 9)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${device.txPower}dBm',
                                    style: AppTheme.dataMono(context, color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Toggle Logging button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLogging) {
                          beaconManager.stopLogging(device);
                        } else {
                          beaconManager.startLogging(device);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLogging
                            ? AppColors.secondaryContainer // Vibrant red
                            : AppColors.primaryContainer,  // Vibrant blue
                        foregroundColor: isLogging
                            ? AppColors.onSecondaryContainer
                            : AppColors.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLogging ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLogging ? '중지' : '시작',
                            style: const TextStyle(
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
          ],
        ),
      ),
    );
  }
}
