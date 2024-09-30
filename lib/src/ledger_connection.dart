import 'package:ledger_flutter_plus/src/api/connection_manager.dart';
import 'package:ledger_flutter_plus/src/concurrency/request_queue.dart';
import 'package:ledger_flutter_plus/src/exceptions/ledger_exception.dart';
import 'package:ledger_flutter_plus/src/ledger/connection_type.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_operation.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_transformer.dart';
import 'package:ledger_flutter_plus/src/models/ledger_device.dart';

class LedgerConnection {
  final RequestQueue _requestQueue = RequestQueue();
  final ConnectionManager _connectionManager;

  final LedgerDevice device;

  bool _isDisconnected = false;
  bool get isDisconnected => _isDisconnected;

  ConnectionType get connectionType => _connectionManager.connectionType;

  LedgerConnection(
    this._connectionManager,
    this.device,
  );

  /// Pending/ongoing requests are cancelled (will throw [StateError])
  Future<void> disconnect() {
    if (_isDisconnected) {
      return Future.value();
    }
    _isDisconnected = true;
    _requestQueue.dispose();
    return _connectionManager.disconnect(device.id);
  }

  Future<T> sendOperation<T>(
    LedgerOperation<T> operation, {
    LedgerTransformer? transformer,
  }) async {
    if (_isDisconnected) {
      throw DeviceNotConnectedException(
        requestedOperation:
            '(_isDisconnected = $_isDisconnected) sendOperation',
        connectionType: _connectionManager.connectionType,
      );
    }

    return _requestQueue.enqueueRequest(
      () => _connectionManager.sendOperation<T>(
        device,
        operation,
        transformer,
      ),
    );
  }
}
