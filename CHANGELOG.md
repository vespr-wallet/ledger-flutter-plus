## 1.5.0

- Updated universal_ble to 0.14.0
- Added handling for multiple ledger device connected in parallel

## Breaking Change

- `deviceStateChanged` is now a function (previously property) which requires the deviceId to be passed so that only relevant events are sent through the stream 

## 1.4.1

- Reverted universal_ble to 0.12.0 because 0.13.0 does not seem to connect at all on iOS

## 1.4.0

- Updated universal_ble package to latest version

## 1.3.0

- Improved BLE reliability
- Checking device connectivity state during [connect] call to avoid re-attempting BLE connection to already connected device
- Requests are now serialized to prevent issues caused by race conditions (they were very common for unawaited requests)

- Added reusable `LedgerSimpleOperation` encapsulating the standard structure of ledger requests
- Added `LedgerComplexOperation` for requests that require multiple (and possibly conditional) chunks of data to be sent as part of a single transaction flow

## Breaking Change

- [ConnectionTimeoutException] is now [EstablishConnectionException] which contains a nested exception for the failure reason

## NOTE

It is **strongly recommended** to extend `LedgerComplexOperation` for transactions requiring multiple chunks of data to be sent because it uses an internal
queue to serialize each chunk and make sure:
1. order is maintained 
2. no other (differnt) operation will send any data/request to Ledger before current transaction is completed

## 1.2.5

- Improved BLE device type detection (thanks to [@konstantinullrich](https://github.com/konstantinullrich))

## 1.2.4

- Improved error reporting
- Added support and detection for all ledger devices (thanks to [@konstantinullrich](https://github.com/konstantinullrich))
- Removed a pointless `disconnect` call which was causing PlatformException (thanks to [@konstantinullrich](https://github.com/konstantinullrich))

## 1.2.3

- Fix connection bug (spotted on Android)

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
