import 'dart:async';

import 'package:ledger_flutter_plus/src/api/connection_manager.dart';
import 'package:ledger_flutter_plus/src/api/gatt_gateway.dart';
import 'package:ledger_flutter_plus/src/exceptions/ledger_exception.dart';
import 'package:ledger_flutter_plus/src/ledger/connection_type.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_gatt_gateway.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_transformer.dart';
import 'package:ledger_flutter_plus/src/ledger_interface.dart';
import 'package:ledger_flutter_plus/src/models/discovered_ledger.dart';
import 'package:ledger_flutter_plus/src/models/ledger_device.dart';
import 'package:ledger_flutter_plus/src/operations/ledger_operations.dart';
import 'package:universal_ble/universal_ble.dart';

const _bleMasterTimeout = Duration(seconds: 60);
const _bleConnectionTimeout = Duration(seconds: 30);
const _bleCheckConnectionTimeout = Duration(seconds: 5);

class LedgerBleConnectionManager extends ConnectionManager {
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

    UniversalBle.timeout = _bleMasterTimeout;

    try {
      final Completer<void> deviceConnected = Completer();

      // ignore: prefer_function_declarations_over_variables
      final OnConnectionChange connChangeListener = (deviceId, isConnected) {
        if (deviceId == device.id && !deviceConnected.isCompleted) {
          if (isConnected) {
            deviceConnected.complete();
          }
          //  else if (error != null) {
          //   deviceConnected.completeError(error);
          // }
        }
      };
      final deviceConnectedFuture = deviceConnected.future.timeout(
        _bleConnectionTimeout,
        onTimeout: () => throw TimeoutException(
          "deviceConnectedFuture",
          _bleConnectionTimeout,
        ),
      );
      deviceConnectedFuture
          .then((_) => _connectionChangeListeners.remove(connChangeListener))
          .catchError(
            (_) => _connectionChangeListeners.remove(connChangeListener),
          );

      _connectionChangeListeners.add(connChangeListener);

      try {
        final connectionState = await UniversalBle //
                .getConnectionState(device.id)
            .timeout(
          _bleCheckConnectionTimeout,
          onTimeout: () => BleConnectionState.disconnected,
        );
        switch (connectionState) {
          case BleConnectionState.connected:
          case BleConnectionState.connecting:
            deviceConnected.complete();
            break;
          case BleConnectionState.disconnected:
          case BleConnectionState.disconnecting:
            // DO NOT AWAIT "connect". It seems to be buggy and not actually complete, despite connChangeListener
            // getting invoked and confirming that the device connected successfully.
            UniversalBle.connect(device.id).ignore();
        }
        await deviceConnectedFuture;
      } catch (e) {
        disconnect(device.id).ignore();
        throw EstablishConnectionException(
          connectionType: ConnectionType.ble,
          nestedError: e,
        );
      }

      final services = await UniversalBle.discoverServices(device.id).timeout(
        _bleConnectionTimeout,
        onTimeout: () => throw TimeoutException(
          "UniversalBle.discoverServices",
          _bleConnectionTimeout,
        ),
      );

      final subscription = _getOrCreateConnectionStateController(device.id);

      final ledger = DiscoveredLedger(
        device: device,
        services: services,
        subscription: subscription.stream.listen((state) {}),
      );

      final gateway = LedgerGattGateway(ledger: ledger);

      await gateway.start().timeout(
            _bleMasterTimeout,
            onTimeout: () => throw TimeoutException(
              "gateway.start",
              _bleMasterTimeout,
            ),
          );
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
    _getOrCreateConnectionStateController(deviceId).add(state);
  }

  StreamController<BleConnectionState> _getOrCreateConnectionStateController(
    String deviceId,
  ) =>
      _connectionStateControllers.putIfAbsent(
        deviceId,
        () => StreamController<BleConnectionState>.broadcast(),
      );

  @override
  Future<T> sendRawOperation<T>(
    LedgerDevice device,
    LedgerRawOperation<T> operation,
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
