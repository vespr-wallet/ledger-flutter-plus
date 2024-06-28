import 'dart:async';

import 'package:ledger_flutter/ledger_flutter.dart';

class LedgerBleConnectionManager extends BleConnectionManager {
  static const serviceId = '13D63400-2C97-0004-0000-4C6564676572';

  final LedgerOptions _options;
  final PermissionRequestCallback? onPermissionRequest;
  final _connectedDevices = <String, GattGateway>{};
  final _bleManager = UniversalBle();
  final _connectionStateControllers =
      <String, StreamController<BleConnectionState>>{};

  LedgerBleConnectionManager({
    required LedgerOptions options,
    this.onPermissionRequest,
  }) : _options = options {
    UniversalBle.onConnectionChange = _handleConnectionChange;
  }

  @override
  Future<void> connect(
    LedgerDevice device, {
    LedgerOptions? options,
  }) async {
    final availabilityState =
        await UniversalBle.getBluetoothAvailabilityState();
    final granted = await onPermissionRequest?.call(availabilityState) ?? true;
    if (!granted) {
      return;
    }

    await disconnect(device);

    final effectiveOptions = options ?? _options;

    UniversalBle.timeout = const Duration(seconds: 60);

    try {
      await UniversalBle.connect(device.id);

      await Future.delayed(const Duration(seconds: 2));

      final services = await UniversalBle.discoverServices(device.id)
          .timeout(const Duration(seconds: 30));

      final subscription =
          await _getOrCreateConnectionStateController(device.id);

      final ledger = DiscoveredLedger(
        device: device,
        services: services,
        subscription: subscription.stream.listen((state) {}),
      );

      final gateway = LedgerGattGateway(
        bleManager: _bleManager,
        ledger: ledger,
        mtu: effectiveOptions.mtu,
      );

      await gateway.start().timeout(const Duration(seconds: 60));
      _connectedDevices[device.id] = gateway;
    } on LedgerException {
      await disconnect(device);
      rethrow;
    } finally {
      UniversalBle.timeout = const Duration(seconds: 60);
    }
  }

  Future<void> _handleConnectionChange(
      String deviceId, bool isConnected) async {
    final state = isConnected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
    final controller = await _getOrCreateConnectionStateController(deviceId);
    controller.add(state);

    if (!isConnected) {
      await disconnect(LedgerDevice(
          id: deviceId, name: '', connectionType: ConnectionType.ble));
    }
  }

  Future<StreamController<BleConnectionState>>
      _getOrCreateConnectionStateController(String deviceId) async {
    return _connectionStateControllers.putIfAbsent(
      deviceId,
      () {
        return StreamController<BleConnectionState>.broadcast();
      },
    );
  }

  @override
  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation,
    LedgerTransformer? transformer,
  ) async {
    final d = _connectedDevices[device.id];
    if (d == null) {
      throw LedgerException(message: 'Unable to send request.');
    }

    return d.sendOperation<T>(
      operation,
      transformer: transformer,
    );
  }

  @override
  Future<AvailabilityState> get status =>
      UniversalBle.getBluetoothAvailabilityState();

  @override
  Stream<AvailabilityState> get statusStateChanges {
    final controller = StreamController<AvailabilityState>();
    UniversalBle.onAvailabilityChange = (state) {
      controller.add(state);
    };
    return controller.stream;
  }

  @override
  List<LedgerDevice> get devices => _connectedDevices.keys
      .map((id) =>
          LedgerDevice(id: id, name: '', connectionType: ConnectionType.ble))
      .toList();

  @override
  Stream<BleConnectionState> get deviceStateChanges {
    final controller = StreamController<BleConnectionState>();
    UniversalBle.onConnectionChange = (String deviceId, bool isConnected) {
      final state = isConnected
          ? BleConnectionState.connected
          : BleConnectionState.disconnected;
      controller.add(state);
    };
    return controller.stream;
  }

  @override
  Future<void> disconnect(LedgerDevice device) async {
    final discoveredLedger = _connectedDevices[device.id];
    if (discoveredLedger != null) {
      await (discoveredLedger as DiscoveredLedger).disconnect();
      _connectedDevices.remove(device.id);
      await UniversalBle.disconnect(device.id);
    }
    _connectionStateControllers[device.id]?.close();
    _connectionStateControllers.remove(device.id);
  }

  @override
  Future<void> dispose() async {
    final deviceIds = List<String>.from(_connectedDevices.keys);
    for (var deviceId in deviceIds) {
      await disconnect(LedgerDevice(
          id: deviceId, name: '', connectionType: ConnectionType.ble));
    }
    _connectedDevices.clear();
    for (var controller in _connectionStateControllers.values) {
      await controller.close();
    }
    _connectionStateControllers.clear();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onAvailabilityChange = null;
  }
}
