import 'package:flutter/services.dart';

class LedgerException implements Exception {
  final String message;
  final Object? cause;
  final int errorCode;

  late String errorCodeHex = "0x${errorCode.toRadixString(16).toUpperCase()}";

  LedgerException({
    this.message = '',
    this.cause,
    required this.errorCode,
  });

  factory LedgerException.fromPlatformException(PlatformException exception) {
    final errorCode = int.tryParse(exception.code) ?? -99;
    final message = exception.message ?? '';
    return LedgerException(
      errorCode: errorCode,
      message: message,
      cause: exception,
    );
  }
}
