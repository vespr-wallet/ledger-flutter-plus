import 'dart:async';

import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:rxdart/subjects.dart';

class LedgerBleSearchManager extends BleSearchManager {
  static const String serviceId = '13D63400-2C97-0004-0000-4C6564676572';
  static const String writeCharacteristicKey =
      '13D63400-2C97-0004-0002-4C6564676572';
  static const String notifyCharacteristicKey =
      '13D63400-2C97-0004-0001-4C6564676572';

  final BluetoothOptions _options;
  final PermissionRequestCallback _onPermissionRequest;

  bool _isScanning = false;
  ReplaySubject<LedgerDevice> _devicesSubject = ReplaySubject<LedgerDevice>();

  LedgerBleSearchManager({
    required BluetoothOptions options,
    required PermissionRequestCallback onPermissionRequest,
  })  : _options = options,
        _onPermissionRequest = onPermissionRequest;

  @override
  Stream<LedgerDevice> scan() async* {
    if (!(await _checkPermissions())) {
      throw PermissionException(connectionType: ConnectionType.ble);
    }
    if (_isScanning) {
      yield* _devicesSubject.stream;
      return;
    }
    _isScanning = true;
    _devicesSubject = ReplaySubject();

    final Set<String> scannedIds = {};

    // attach BLE listener
    UniversalBle.onScanResult = (device) {
      if (scannedIds.contains(device.deviceId)) {
        return;
      }

      final lDevice = LedgerDevice.ble(
        id: device.deviceId,
        name: device.name ?? '',
        rssi: device.rssi ?? 0,
      );

      scannedIds.add(lDevice.id);
      if (_devicesSubject.isClosed) {
        // ignore: avoid_print
        print(
          "UniversalBle.onScanResult: Unexpected device scan intercepted after stream closed",
        );
        return;
      } else {
        _devicesSubject.add(lDevice);
      }
    };

    _performBleScan();

    yield* _devicesSubject.stream;
  }

  Future<bool> _checkPermissions() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return await _onPermissionRequest(state);
  }

  Future<void> _performBleScan() async {
    try {
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [serviceId]),
      );

      await Future.delayed(_options.maxScanDuration);
    } finally {
      await stop();
    }
  }

  @override
  Future<void> stop() async {
    if (!_isScanning) {
      return;
    }

    try {
      _isScanning = false;
      await UniversalBle.stopScan();
    } finally {
      unawaited(_devicesSubject.close());
      UniversalBle.onScanResult = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  /// Returns the current status of the BLE subsystem of the host device.
  Future<AvailabilityState> get status =>
      UniversalBle.getBluetoothAvailabilityState();
}
