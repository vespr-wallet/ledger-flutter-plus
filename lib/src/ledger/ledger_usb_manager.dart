import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ledger_flutter/ledger_flutter.dart';
import 'package:ledger_flutter/src/api/connection_manager.dart';
import 'package:ledger_usb_plus/ledger_usb.dart';
import 'package:ledger_usb_plus/usb_device.dart';
import 'package:universal_platform/universal_platform.dart';

class LedgerUsbManager extends ConnectionManager {
  bool _disposed = false;

  final _ledgerUsb = LedgerUsb();
  final void Function() onDispose;

  LedgerUsbManager({required this.onDispose});

  @override
  Future<void> connect(LedgerDevice device, {LedgerOptions? options}) async {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    try {
      final usbDevice = UsbDevice.fromIdentifier(device.id);
      await _ledgerUsb.requestPermission(usbDevice);
      await _ledgerUsb.open(usbDevice);
    } on PlatformException catch (ex) {
      throw LedgerDeviceException.fromPlatformException(ex);
    }
  }

  @override
  Future<void> disconnect(LedgerDevice device) async {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    try {
      await _ledgerUsb.close();
    } on PlatformException catch (ex) {
      throw LedgerDeviceException.fromPlatformException(ex);
    }
  }

  @override
  Future<T> sendOperation<T>(
    LedgerDevice device,
    LedgerOperation<T> operation,
    LedgerTransformer? transformer,
  ) async {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    try {
      final writer = ByteDataWriter();
      final apdus = await operation.write(writer);
      final response = await _ledgerUsb.exchange(apdus);
      final reader = ByteDataReader();
      if (transformer != null) {
        final transformed = await transformer.onTransform(response);
        reader.add(transformed);
      } else {
        reader.add(response.expand((e) => e).toList());
      }

      return operation.read(reader);
    } on PlatformException catch (ex) {
      throw LedgerDeviceException.fromPlatformException(ex);
    }
  }

  @override // TODO this may need to be implemented
  Stream<BleConnectionState> get deviceStateChanges {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    return const Stream.empty();
  }

  @override
  Future<List<LedgerDevice>> get devices async {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    try {
      final devices = await _ledgerUsb.listDevices();
      return devices
          .map((device) => LedgerDevice.fromUsbDevice(device))
          .toList();
    } on PlatformException catch (ex) {
      throw LedgerDeviceException.fromPlatformException(ex);
    }
  }

  @override
  Future<AvailabilityState> get status async => UniversalPlatform.isIOS
      ? AvailabilityState.unsupported
      : AvailabilityState.poweredOn;

  @override
  Stream<AvailabilityState> get statusStateChanges {
    if (_disposed) throw LedgerManagerDisposedException(connectionType);

    return const Stream.empty();
  }

  @override
  final ConnectionType connectionType = ConnectionType.usb;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      await _ledgerUsb.close();
    } on PlatformException catch (ex) {
      throw LedgerDeviceException.fromPlatformException(ex);
    } finally {
      onDispose();
    }
  }
}
