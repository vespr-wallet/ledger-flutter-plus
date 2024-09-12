import 'package:ledger_flutter_plus/src/ledger/connection_type.dart';
import 'package:ledger_flutter_plus/src/ledger/ledger_ble_device_info.dart';
import 'package:ledger_usb_plus/usb_device.dart';

class LedgerDevice {
  final String id;
  final String name;
  final ConnectionType connectionType;
  final int rssi;
  final LedgerBleDeviceInfo? deviceInfo;

  LedgerDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    this.rssi = 0,
    this.deviceInfo,
  });

  factory LedgerDevice.ble({
    required String id,
    required String name,
    int rssi = 0,
    LedgerBleDeviceInfo deviceInfo = LedgerBleDeviceInfo.stax,
  }) =>
      LedgerDevice(
          id: id,
          name: name,
          connectionType: ConnectionType.ble,
          rssi: rssi,
          deviceInfo: deviceInfo);

  factory LedgerDevice.usb(UsbDevice device) => LedgerDevice(
        id: device.identifier,
        name: device.productName,
        connectionType: ConnectionType.usb,
      );

  LedgerDevice copyWith({
    String Function()? id,
    String Function()? name,
    ConnectionType Function()? connectionType,
    int Function()? rssi,
    LedgerBleDeviceInfo? Function()? deviceInfo,
  }) {
    return LedgerDevice(
      id: id != null ? id() : this.id,
      name: name != null ? name() : this.name,
      connectionType:
          connectionType != null ? connectionType() : this.connectionType,
      rssi: rssi != null ? rssi() : this.rssi,
      deviceInfo: deviceInfo != null ? deviceInfo() : this.deviceInfo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
