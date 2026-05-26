import 'package:flutter/material.dart';
import '../models/beacon_device.dart';
import '../services/beacon_manager.dart';
import '../theme/theme.dart';

class DeviceDetailScreen extends StatefulWidget {
  final BeaconDevice device;
  final BeaconManager beaconManager;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.beaconManager,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final ScrollController _terminalScrollController = ScrollController();
  List<String> _terminalLogs = [];
  int _lastDisplayedPacketCount = -1;
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _terminalScrollController.dispose();
    super.dispose();
  }

  /// Loads logs from the beacon manager (either active or historical)
  Future<void> _loadLogs() async {
    if (_isLoadingLogs) return;
    setState(() {
      _isLoadingLogs = true;
    });

    try {
      final logs = await widget.beaconManager.getTerminalLogs(widget.device);
      if (mounted) {
        setState(() {
          _terminalLogs = logs;
          _isLoadingLogs = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _terminalLogs = ['[SYSTEM] Error loading logs: $e'];
          _isLoadingLogs = false;
        });
      }
    }
  }

  /// Automatically scrolls the terminal to the bottom
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.beaconManager,
      builder: (context, _) {
        final isLogging = widget.device.isLogging;

        // Check if we are logging, and whether we should refresh the terminal.
        // Rule: Update terminal output only once every 10 data packets during active logging.
        if (isLogging) {
          final currentPackets = widget.device.packetCount;
          if (currentPackets != _lastDisplayedPacketCount && currentPackets % 10 == 0) {
            _lastDisplayedPacketCount = currentPackets;
            // Fetch updated logs
            _loadLogs();
          }
        } else {
          // If logging is stopped, reset our tracker so it works if started again
          _lastDisplayedPacketCount = -1;
        }

        // Define RSSI icon & color
        IconData signalIcon;
        Color signalColor;
        if (widget.device.rssi >= -65) {
          signalIcon = Icons.signal_cellular_alt_rounded;
          signalColor = AppColors.signalGreen;
        } else if (widget.device.rssi >= -80) {
          signalIcon = Icons.signal_cellular_alt_2_bar_rounded;
          signalColor = AppColors.primary;
        } else {
          signalIcon = Icons.signal_cellular_alt_1_bar_rounded;
          signalColor = AppColors.textSecondary;
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Device Detail',
              style: AppTheme.headlineMd(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              // Recording status pill in AppBar
              if (isLogging) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PulseDot(),
                      const SizedBox(width: 6),
                      Text(
                        'REC',
                        style: AppTheme.labelCaps(context).copyWith(
                          color: AppColors.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Status Header (Compact Device Card)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // UUID and RSSI
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UUID', style: AppTheme.labelCaps(context)),
                                const SizedBox(height: 4),
                                Text(
                                  widget.device.uuid,
                                  style: AppTheme.dataMono(context, color: AppColors.primary, size: 14),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(signalIcon, color: signalColor, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.device.displayedRssi} dBm',
                                    style: AppTheme.dataMono(context, color: signalColor, size: 18).copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('RSSI STRENGTH', style: AppTheme.labelCaps(context).copyWith(fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 4-Column Grid for Details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 3.0,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _GridItem(label: 'MAC ADDRESS', value: widget.device.mac),
                            _GridItem(label: 'TX POWER', value: '${widget.device.txPower} dBm'),
                            _GridItem(label: 'MAJOR', value: '${widget.device.major}'),
                            _GridItem(label: 'MINOR', value: '${widget.device.minor}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Action Logging Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (isLogging) {
                              await widget.beaconManager.stopLogging(widget.device);
                            } else {
                              await widget.beaconManager.startLogging(widget.device);
                            }
                            _loadLogs(); // Instantly refresh logs
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
                          child: Text(
                            isLogging ? 'STOP LOGGING' : 'START LOGGING',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 2. Terminal Section
              Expanded(
                child: Container(
                  color: AppColors.terminalBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Terminal Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'RAW TELEMETRY LOG',
                              style: AppTheme.labelCaps(context).copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            if (_isLoadingLogs)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Terminal Console Log Lines
                      Expanded(
                        child: _terminalLogs.isEmpty
                            ? Center(
                                child: Text(
                                  '수집된 로그 데이터가 없습니다.\nSTART LOGGING 버튼을 눌러 기록을 시작하세요.',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.dataMonoSm(context).copyWith(
                                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _terminalScrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: _terminalLogs.length,
                                itemBuilder: (context, index) {
                                  final log = _terminalLogs[index];
                                  
                                  // Formatting console line coloring
                                  Color logColor = AppColors.textPrimary;
                                  if (log.contains('Start logging')) {
                                    logColor = AppColors.primary;
                                  } else if (log.contains('Logging stopped')) {
                                    logColor = AppColors.secondary;
                                  } else if (log.contains('[SYSTEM]')) {
                                    logColor = AppColors.textSecondary;
                                  } else {
                                    // Make packets alternate in color or look neutral
                                    logColor = const Color(0xFFE2E8F0);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: Colors.transparent, width: 2),
                                        ),
                                      ),
                                      child: Text(
                                        log,
                                        style: AppTheme.dataMonoSm(context, color: logColor),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper widget for the 2x2 details grid inside the Status Header
class _GridItem extends StatelessWidget {
  final String label;
  final String value;

  const _GridItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTheme.labelCaps(context).copyWith(
            fontSize: 9,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.dataMono(context, color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Internal Pulsing Dot for REC pill
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.secondaryContainer,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
