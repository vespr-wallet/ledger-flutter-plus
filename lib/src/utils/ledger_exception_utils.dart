import 'package:flutter/services.dart';
import 'package:ledger_flutter_plus/src/exceptions/ledger_exception.dart';

import '../ledger/connection_type.dart';

class LedgerExceptionUtils {
  const LedgerExceptionUtils._();

  static LedgerException fromPlatformException(
    PlatformException exception,
    ConnectionType connectionType,
  ) {
    final errorCode = int.tryParse(exception.code) ?? 0;
    final message = exception.message ?? '';

    if (message == "connectionLost") {
      return ConnectionLostException(connectionType: connectionType);
    }
    return LedgerDeviceException(
      errorCode: errorCode,
      message: message,
      cause: exception,
      connectionType: connectionType,
    );
  }
}
