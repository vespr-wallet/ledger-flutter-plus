import 'package:ledger_flutter_plus/src/api/connection_manager.dart';
import 'package:ledger_flutter_plus/src/concurrency/request_queue.dart';
import 'package:ledger_flutter_plus/src/exceptions/ledger_exception.dart';
import 'package:ledger_flutter_plus/src/ledger/connection_type.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_transformer.dart';
import 'package:ledger_flutter_plus/src/models/ledger_device.dart';
import 'package:ledger_flutter_plus/src/operations/ledger_operations.dart';

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
      () => _sendOperationImpl(device, operation, transformer),
    );
  }

  /// Sends a Ledger operation to the device.
  /// Careful when calling this method because it doesn't queue the operation.
  Future<T> _sendOperationImpl<T>(
    LedgerDevice device,
    LedgerOperation<T> operation,
    LedgerTransformer? transformer,
  ) async {
    switch (operation) {
      case LedgerRawOperation<T>():
        return _connectionManager.sendRawOperation<T>(
          device,
          operation,
          transformer,
        );
      case LedgerComplexOperation<T>():
        // We need to use a nested request queue to ensure that each inner operation
        //   has all send calls executed in the same order as they were called
        //   even if the operation is unawaited.
        final RequestQueue nestedRequestQueue = RequestQueue();
        Future<Y> send<Y>(LedgerOperation<Y> simpleOp) =>
            nestedRequestQueue.enqueueRequest(
              () => _sendOperationImpl(device, simpleOp, transformer),
            );
        return await operation.invoke(send);
    }
  }
}
