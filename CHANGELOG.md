## 1.0.8

- Small internal changes to expose some classes via `ledger_flutter_plus_dart.dart` (no flutter imports)

## 1.0.7

## Breaking Changes

- Improved API for connecting to ledger and managing active connection(s)

## 1.0.6

## Breaking Changes

- Removed some optional LedgerOptions that could be passed for connect/scan
- Renamed `LedgerOptions` to `BluetoothOptions`
- Removed possibility to pass `mtu` option

## 1.0.5

- Improved disposal management

## 1.0.4

- Some internal cleanup and changes to return correct LedgerDevice object (including name/etc)

## Breaking Change

- Changed `disconnect` do be done by deviceId instead of `LedgerDevice` object

## 1.0.3

- Added connection lost error

## BREAKING

- Instantiate from now on using LedgerInterface.usb and LedgerInterface.ble

## 1.0.2

- Added WEB support for both usb and ble

## 1.0.1

- Changed package name

## 1.0.0

- Initial release.
