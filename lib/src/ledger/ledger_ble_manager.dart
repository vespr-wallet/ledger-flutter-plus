import 'dart:async';

import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

const _bleMasterTimeout = Duration(seconds: 60);
const _bleConnectionTimeout = Duration(seconds: 30);

class LedgerBleConnectionManager extends ConnectionManager {
  static const ledgerNanoXServiceId = '13D63400-2C97-0004-0000-4C6564676572';

  bool _disposed = false;

  final PermissionRequestCallback onPermissionRequest;

  final _connectedDevices =
      <String, ({GattGateway gateway, LedgerDevice device})>{};
  final _connectionStateControllers =
      <String, StreamController<BleConnectionState>>{};

  final List<OnConnectionChange> _connectionChangeListeners = [];

  final _onConnectionChangeController = StreamController<BleConnectionState>();
  final _statusStateChangesController = StreamController<AvailabilityState>();

  LedgerBleConnectionManager({
    required this.onPermissionRequest,
  }) {
    _connectionChangeListeners.add(_handleConnectionChange);
    UniversalBle.onConnectionChange = (deviceId, isConnected) {
      // TODO this is not correct cause it doesn't account for deviceId
      final state = isConnected
          ? BleConnectionState.connected
          : BleConnectionState.disconnected;
      _onConnectionChangeController.add(state);

      // Copy the list because we get a ConcurrentModificationError otherwise
      final connectionChangeListeners = List.from(
        _connectionChangeListeners,
        growable: false,
      );

      for (final listener in connectionChangeListeners) {
        listener(deviceId, isConnected);
      }
    };
  }

  @override
  Future<void> connect(LedgerDevice device) async {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    final availabilityState =
        await UniversalBle.getBluetoothAvailabilityState();
    final granted = await onPermissionRequest(availabilityState);
    if (!granted) {
      return;
    }

    await disconnect(device.id);

    UniversalBle.timeout = _bleMasterTimeout;

    try {
      final Completer<void> deviceConnected = Completer();
      late final OnConnectionChange connChangeListener;
      connChangeListener = (deviceId, isConnected) {
        if (deviceId == device.id && isConnected) {
          deviceConnected.complete();
          _connectionChangeListeners.remove(connChangeListener);
        }
      };
      _connectionChangeListeners.add(connChangeListener);

      await UniversalBle.connect(device.id);
      try {
        await deviceConnected.future.timeout(_bleConnectionTimeout);
      } catch (e) {
        _connectionChangeListeners.remove(connChangeListener);
        unawaited(disconnect(device.id));
        throw ConnectionTimeoutException(
          connectionType: ConnectionType.ble,
          timeout: _bleConnectionTimeout,
        );
      }

      final services = await UniversalBle.discoverServices(device.id)
          .timeout(_bleConnectionTimeout);

      final subscription =
          await _getOrCreateConnectionStateController(device.id);

      final ledger = DiscoveredLedger(
        device: device,
        services: services,
        subscription: subscription.stream.listen((state) {}),
      );

      final gateway = LedgerGattGateway(ledger: ledger);

      await gateway.start().timeout(_bleMasterTimeout);
      _connectedDevices[device.id] = (gateway: gateway, device: device);
    } on LedgerException {
      await disconnect(device.id);
      rethrow;
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
      await disconnect(deviceId);
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
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    final d = _connectedDevices[device.id];
    if (d == null) {
      throw DeviceNotConnectedException(
        requestedOperation: 'ble_manager: sendOperation',
        connectionType: ConnectionType.ble,
      );
    }

    return d.gateway.sendOperation<T>(
      operation,
      transformer: transformer,
    );
  }

  @override
  Future<AvailabilityState> get status {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    return UniversalBle.getBluetoothAvailabilityState();
  }

  @override
  Stream<AvailabilityState> get statusStateChanges {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    UniversalBle.onAvailabilityChange = (state) {
      _statusStateChangesController.add(state);
    };
    return _statusStateChangesController.stream;
  }

  @override
  Future<List<LedgerDevice>> get devices async {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    return _connectedDevices.values.map((e) => e.device).toList();
  }

  @override
  Stream<BleConnectionState> get deviceStateChanges {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    return _onConnectionChangeController.stream;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    await _disconnect(deviceId);
  }

  // Bypass dispose check here because this method is called from dispose
  Future<void> _disconnect(String deviceId) async {
    final gateway = _connectedDevices.remove(deviceId)?.gateway;
    if (gateway != null) {
      // UniversalBle.disconnect is called internally by gateway.disconnect
      await gateway.disconnect();
    } else {
      await UniversalBle.disconnect(deviceId);
    }

    _connectionStateControllers.remove(deviceId)?.close();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _onConnectionChangeController.close();
    _statusStateChangesController.close();

    final deviceIds = List<String>.from(_connectedDevices.keys);
    for (final deviceId in deviceIds) {
      try {
        await _disconnect(deviceId);
      } catch (e) {
        // ignore
      }
    }
    _connectedDevices.clear();
    for (final controller in _connectionStateControllers.values) {
      try {
        await controller.close();
      } catch (e) {
        // ignore
      }
    }
    _connectionStateControllers.clear();
    UniversalBle.onConnectionChange = null;
    UniversalBle.onAvailabilityChange = null;
  }

  @override
  final ConnectionType connectionType = ConnectionType.ble;
}
