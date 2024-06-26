import 'dart:async';

import 'package:ledger_flutter/ledger_flutter.dart';

class LedgerBleConnectionManager extends BleConnectionManager {
  static const serviceId = '13D63400-2C97-0004-0000-4C6564676572';

  final LedgerOptions _options;
  final PermissionRequestCallback? onPermissionRequest;
  final _connectedDevices = <LedgerDevice, GattGateway>{};
  final _bleManager = UniversalBle();

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

    try {
      await UniversalBle.connect(
        device.id,
        connectionTimeout:
            options?.connectionTimeout ?? _options.connectionTimeout,
      );

      final services = await UniversalBle.discoverServices(device.id);

      final subscription = StreamController<BleConnectionState>.broadcast();
      UniversalBle.onConnectionChange = (String deviceId, bool isConnected) {
        if (deviceId == device.id) {
          final state = isConnected
              ? BleConnectionState.connected
              : BleConnectionState.disconnected;
          subscription.add(state);
          if (!isConnected) {
            disconnect(device);
          }
        }
      };

      final ledger = DiscoveredLedger(
        device: device,
        services: services,
        subscription: subscription.stream.listen((state) {}),
      );

      final gateway = LedgerGattGateway(
        bleManager: _bleManager,
        ledger: ledger,
        mtu: options?.mtu ?? _options.mtu,
      );

      await gateway.start();
      _connectedDevices[device] = gateway;
    } catch (ex) {
      await disconnect(device);
      rethrow;
    }
  }

  void _handleConnectionChange(String deviceId, bool isConnected) {
    if (!isConnected) {
      final device = _connectedDevices.keys.firstWhere((d) => d.id == deviceId);
      disconnect(device);
    }
  }

  @override
  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation,
    LedgerTransformer? transformer,
  ) async {
    final d = _connectedDevices[device];
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
    UniversalBle.onAvailabilityChange = controller.add;
    return controller.stream;
  }

  @override
  List<LedgerDevice> get devices => _connectedDevices.keys.toList();

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
    final discoveredLedger = _connectedDevices[device] as DiscoveredLedger?;
    await discoveredLedger?.disconnect();
    _connectedDevices.remove(device);
    await UniversalBle.disconnect(device.id);
  }

  @override
  Future<void> dispose() async {
    for (var device in _connectedDevices.keys) {
      await disconnect(device);
    }
    _connectedDevices.clear();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onAvailabilityChange = null;
  }
}
