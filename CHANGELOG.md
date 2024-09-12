## 1.2.2

- Added explicit BLE pair check and pair request if not paired

## 1.2.1

- Fixed `ConcurrentModificationError` thrown when trying to connect device

## 1.2.0

- Updated major universal_ble version

## 1.1.1

- Fixed BLE Manager dispose (previously not disconnecting ledger device on dispose)

## 1.1.0

- Updated universal_ble and ledger_usb_plus versions
- Fixed merging of partial BLE responses of max 20 bytes (observed on some android devices)

## 1.0.11

- Made LedgerDevice constructor public

## 1.0.10

- Improved BLE handling for scanning / stopping scanning
- Exported a few more classes

## 1.0.9

- [Fix from 1.0.8] Small internal changes to expose some classes via `ledger_flutter_plus_dart.dart` (no flutter imports)

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
