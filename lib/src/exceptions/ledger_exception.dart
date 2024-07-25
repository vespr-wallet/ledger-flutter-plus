import 'package:ledger_flutter_plus/src/ledger/connection_type.dart';

sealed class LedgerException implements Exception {}

class ConnectionTimeoutException extends LedgerException {
  final ConnectionType connectionType;
  final Duration timeout;

  ConnectionTimeoutException({
    required this.connectionType,
    required this.timeout,
  });
}

class ConnectionLostException extends LedgerException {
  final ConnectionType connectionType;

  ConnectionLostException({
    required this.connectionType,
  });
}

class LedgerManagerDisposedException extends LedgerException {
  final ConnectionType connectionType;

  LedgerManagerDisposedException(this.connectionType);
}

class DisposeException extends LedgerException {
  final ConnectionType connectionType;
  final Object? cause;

  DisposeException({
    required this.connectionType,
    required this.cause,
  });
}

class DeviceNotConnectedException extends LedgerException {
  final ConnectionType connectionType;
  final String requestedOperation;

  DeviceNotConnectedException({
    required this.connectionType,
    required this.requestedOperation,
  });
}

class ServiceNotSupportedException extends LedgerException {
  final ConnectionType connectionType;
  final String message;
  final Object? nestedError;

  ServiceNotSupportedException({
    required this.connectionType,
    required this.message,
    this.nestedError,
  });
}

class LedgerDeviceException extends LedgerException {
  final String message;
  final Object? cause;
  final int errorCode;
  final ConnectionType connectionType;

  LedgerDeviceException({
    this.message = '',
    this.cause,
    this.errorCode = 0x6F00,
    required this.connectionType,
  });
}
