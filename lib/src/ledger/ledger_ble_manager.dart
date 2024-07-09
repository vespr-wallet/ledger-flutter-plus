import 'dart:async';

import 'package:ledger_flutter/ledger_flutter.dart';

const _bleMasterTimeout = Duration(seconds: 60);
const _bleConnectionTimeout = Duration(seconds: 30);

class LedgerBleConnectionManager extends ConnectionManager {
  static const ledgerNanoXServiceId = '13D63400-2C97-0004-0000-4C6564676572';

  bool _disposed = false;

  final LedgerOptions _options;
  final PermissionRequestCallback onPermissionRequest;
  final void Function() onDispose;

  final _connectedDevices = <String, GattGateway>{};
  final _connectionStateControllers =
      <String, StreamController<BleConnectionState>>{};

  final List<OnConnectionChange> _connectionChangeListeners = [];

  final _onConnectionChangeController = StreamController<BleConnectionState>();
  final _statusStateChangesController = StreamController<AvailabilityState>();

  LedgerBleConnectionManager(
    this._options, {
    required this.onPermissionRequest,
    required this.onDispose,
  }) {
    _connectionChangeListeners.add(_handleConnectionChange);
    UniversalBle.onConnectionChange = (deviceId, isConnected) {
      // TODO this is not correct cause it doesn't account for deviceId
      final state = isConnected
          ? BleConnectionState.connected
          : BleConnectionState.disconnected;
      _onConnectionChangeController.add(state);

      for (var listener in _connectionChangeListeners) {
        listener(deviceId, isConnected);
      }
    };
  }

  @override
  Future<void> connect(
    LedgerDevice device, {
    LedgerOptions? options,
  }) async {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    final availabilityState =
        await UniversalBle.getBluetoothAvailabilityState();
    final granted = await onPermissionRequest(availabilityState);
    if (!granted) {
      return;
    }

    await disconnect(device);

    final effectiveOptions = options ?? _options;

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
        unawaited(disconnect(device));
        throw ConnectionTimeoutException(
          connectionType: ConnectionType.ble,
          timeout: _bleConnectionTimeout,
        );
      }

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
        ledger: ledger,
        mtu: effectiveOptions.mtu,
      );

      await gateway.start().timeout(const Duration(seconds: 60));
      _connectedDevices[device.id] = gateway;
    } on LedgerException {
      await disconnect(device);
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
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    final d = _connectedDevices[device.id];
    if (d == null) {
      throw DeviceNotConnectedException(
        requestedOperation: 'sendOperation',
        connectionType: ConnectionType.ble,
      );
    }

    return d.sendOperation<T>(
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

    return _connectedDevices.keys
        .map(
          (id) => LedgerDevice(
            id: id,
            name: '',
            connectionType: ConnectionType.ble,
          ),
        )
        .toList();
  }

  @override
  Stream<BleConnectionState> get deviceStateChanges {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    return _onConnectionChangeController.stream;
  }

  @override
  Future<void> disconnect(LedgerDevice device) async {
    if (_disposed) throw LedgerManagerDisposedException(ConnectionType.ble);

    final gateway = _connectedDevices.remove(device.id);
    if (gateway != null) {
      await gateway.disconnect();
      await UniversalBle.disconnect(device.id);
    }

    _connectionStateControllers.remove(device.id)?.close();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      _onConnectionChangeController.close();
      _statusStateChangesController.close();

      final deviceIds = List<String>.from(_connectedDevices.keys);
      for (final deviceId in deviceIds) {
        try {
          await disconnect(
            LedgerDevice(
              id: deviceId,
              name: '',
              connectionType: ConnectionType.ble,
            ),
          );
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
    } finally {
      onDispose();
    }
  }

  @override
  final ConnectionType connectionType = ConnectionType.ble;
}
