import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'beacon_device.dart';

class BeaconParser {
  /// Parses a [ScanResult] from flutter_blue_plus into a [BeaconDevice] if it matches the iBeacon spec.
  /// Returns null if it is not an iBeacon.
  static BeaconDevice? parse(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    
    // Apple Manufacturer ID is 76 (0x004C)
    if (!manufacturerData.containsKey(76)) {
      return null;
    }

    final data = manufacturerData[76]!;
    
    // iBeacon manufacturer data must be at least 23 bytes:
    // Byte 0: 0x02 (iBeacon type)
    // Byte 1: 0x15 (remaining data length: 21 bytes)
    // Byte 2-17: UUID (16 bytes)
    // Byte 18-19: Major (2 bytes)
    // Byte 20-21: Minor (2 bytes)
    // Byte 22: TX Power (1 byte, signed)
    if (data.length < 23) {
      return null;
    }

    if (data[0] != 0x02 || data[1] != 0x15) {
      return null;
    }

    // 1. Parse UUID (16 bytes from index 2 to 17)
    final uuidBytes = data.sublist(2, 18);
    final uuid = _bytesToUuidString(uuidBytes);

    // 2. Parse Major (2 bytes, big-endian)
    final major = (data[18] << 8) | data[19];

    // 3. Parse Minor (2 bytes, big-endian)
    final minor = (data[20] << 8) | data[21];

    // 4. Parse TX Power (1 byte, signed 8-bit integer)
    int txPower = data[22];
    if (txPower >= 128) {
      txPower -= 256;
    }

    return BeaconDevice(
      uuid: uuid,
      mac: result.device.remoteId.str.toUpperCase(),
      major: major,
      minor: minor,
      txPower: txPower,
      rssi: result.rssi,
    );
  }

  /// Converts 16 bytes into a standard UUID string: 8-4-4-4-12 in uppercase.
  static String _bytesToUuidString(List<int> bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      final hex = bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase();
      buffer.write(hex);
      if (i == 3 || i == 5 || i == 7 || i == 9) {
        buffer.write('-');
      }
    }
    return buffer.toString();
  }
}
