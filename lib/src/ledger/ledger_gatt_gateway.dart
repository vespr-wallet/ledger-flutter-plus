import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:ledger_flutter_plus/src/operations/ledger_operations.dart';

class LedgerGattGateway extends GattGateway {
  final BlePacker _packer;
  final DiscoveredLedger ledger;
  final LedgerGattReader _gattReader;

  BleCharacteristic? characteristicWrite;
  BleCharacteristic? characteristicNotify;
  int _mtu;

  final _pendingOperations = ListQueue<_Request>();
  final Function? _onError;

  LedgerGattGateway({
    required this.ledger,
    LedgerGattReader? gattReader,
    BlePacker? packer,
    int mtu = 23,
    Function? onError,
  })  : _gattReader = gattReader ?? LedgerGattReader(),
        _packer = packer ?? LedgerPacker(),
        _mtu = mtu,
        _onError = onError;

  @override
  Future<void> start() async {
    try {
      final supported = await isRequiredServiceSupported();
      if (!supported) {
        throw ServiceNotSupportedException(
          connectionType: ConnectionType.ble,
          message: 'Required service not supported. '
              'Write characteristic: ${characteristicWrite != null}, '
              'Notify characteristic: ${characteristicNotify != null}',
        );
      }

      if (!kIsWeb) {
        try {
          _mtu = await UniversalBle.requestMtu(ledger.device.id, _mtu);
        } catch (e) {
          _mtu = 23;
        }
      } else {
        _mtu = 23;
      }

      final isPaired = await UniversalBle.isPaired(ledger.device.id);

      final pairCompleter = Completer<void>();
      if (isPaired == false) {
        try {
          UniversalBle.onPairingStateChange = (deviceId, isPaired) {
            if (isPaired) {
              pairCompleter.complete();
            } else {
              pairCompleter.completeError(Exception('Failed to pair'));
            }
          };
          await UniversalBle.pair(ledger.device.id);
        } catch (err) {
          pairCompleter.completeError(err);
        }
      } else {
        pairCompleter.complete();
      }
      try {
        await pairCompleter.future;
      } finally {
        UniversalBle.onPairingStateChange = (deviceId, isPaired) {};
      }

      try {
        if (characteristicNotify != null &&
            characteristicNotify!.properties
                .contains(CharacteristicProperty.notify)) {
          await UniversalBle.setNotifiable(
            ledger.device.id,
            ledger.device.deviceInfo.serviceId,
            ledger.device.deviceInfo.notifyCharacteristicKey,
            BleInputProperty.notification,
          );
        } else {
          throw ServiceNotSupportedException(
            connectionType: ConnectionType.ble,
            message: 'Notify characteristic does not support notifications',
          );
        }
      } catch (e) {
        throw ServiceNotSupportedException(
          connectionType: ConnectionType.ble,
          message: 'Failed to set notifiable: $e',
        );
      }

      UniversalBle.onValueChange =
          (deviceId, characteristicId, final rawData) async {
        if (_pendingOperations.isEmpty) {
          return;
        }

        try {
          final request = _pendingOperations.first;
          request.addData(rawData);

          if (!request.isComplete) {
            return;
          }
          final data = request.data;

          final transformer = request.transformer;
          final reader = ByteDataReader();
          if (transformer != null) {
            final transformed = await transformer.onTransform([data]);
            reader.add(transformed);
          } else {
            reader.add(data);
          }

          final response = await request.operation.read(reader);

          _pendingOperations.removeFirst();
          request.completer.complete(response);
        } catch (ex) {
          _handleOnError(ex);
          _onError?.call(ex);
        }
      };
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _gattReader.close();
    _pendingOperations.clear();
    await UniversalBle.disconnect(ledger.device.id);
  }

  @override
  Future<T> sendOperation<T>(
    LedgerRawOperation operation, {
    LedgerTransformer? transformer,
  }) async {
    final supported = await isRequiredServiceSupported();
    if (!supported) {
      throw ServiceNotSupportedException(
        connectionType: ConnectionType.ble,
        message: 'Required service not supported. '
            'Write characteristic: ${characteristicWrite != null}, '
            'Notify characteristic: ${characteristicNotify != null}',
      );
    }

    var completer = Completer<T>.sync();
    _pendingOperations.addFirst(_Request(operation, transformer, completer));

    final writer = ByteDataWriter();
    final output = await operation.write(writer);
    for (var payload in output) {
      final packets = _packer.pack(payload, _mtu);

      for (var packet in packets) {
        await UniversalBle.writeValue(
          ledger.device.id,
          ledger.device.deviceInfo.serviceId,
          characteristicWrite!.uuid,
          packet,
          BleOutputProperty.withResponse,
        );
      }
    }

    return completer.future;
  }

  @override
  Future<bool> isRequiredServiceSupported() async {
    characteristicWrite = null;
    characteristicNotify = null;

    try {
      final bleDeviceInfo = ledger.device.deviceInfo;
      final service = await getService(bleDeviceInfo.serviceId);
      if (service != null) {
        characteristicWrite = await getCharacteristic(
          service,
          bleDeviceInfo.writeCharacteristicKey,
        );
        characteristicNotify = await getCharacteristic(
          service,
          bleDeviceInfo.notifyCharacteristicKey,
        );
      }
    } catch (e) {
      throw ServiceNotSupportedException(
        connectionType: ConnectionType.ble,
        nestedError: e,
        message: 'Required service not supported. '
            'Write characteristic: ${characteristicWrite != null}, '
            'Notify characteristic: ${characteristicNotify != null}',
      );
    }

    final isSupported = characteristicWrite != null &&
        characteristicNotify != null &&
        characteristicWrite!.properties
            .contains(CharacteristicProperty.write) &&
        characteristicNotify!.properties
            .contains(CharacteristicProperty.notify);
    return isSupported;
  }

  @override
  Future<BleCharacteristic?> getCharacteristic(
    BleService service,
    String characteristic,
  ) async {
    try {
      final targetUuid = characteristic.toLowerCase();
      final result = service.characteristics.firstWhere(
        (c) => c.uuid.toLowerCase() == targetUuid,
        orElse: () => throw Exception('Characteristic not found'),
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  @override
  void onServicesInvalidated() {
    characteristicWrite = null;
    characteristicNotify = null;
  }

  int get mtu => _mtu;

  @override
  Future<BleService?> getService(String serviceId) async {
    try {
      final services = await UniversalBle.discoverServices(ledger.device.id);

      final targetUuid = serviceId.toLowerCase();

      final foundService = services.firstWhere(
        (s) =>
            s.uuid.toLowerCase() == targetUuid ||
            s.uuid.toLowerCase().startsWith(serviceId.toLowerCase()),
        orElse: () => throw Exception('Service not found'),
      );

      return foundService;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await disconnect();
  }

  void _handleOnError(dynamic ex) {
    if (_pendingOperations.isEmpty) {
      return;
    }

    final request = _pendingOperations.removeFirst();
    request.completer.completeError(ex);
  }
}

class _Request {
  final LedgerRawOperation operation;
  final LedgerTransformer? transformer;
  final Completer completer;

  final Map<int, Uint8List> _partialData = {};
  int _expectedDataLength = -1; // read from packet 0

  void addData(Uint8List data) {
    // First packet should be at least 5 bytes long
    // Rest should be at least 3 bytes long
    if (data.length < 3 || (data[2] == 0 && data.length < 5)) {
      throw UnexpectedDataPacketException(
        data: data,
        reason: UnexpectedDataPacketReason.tooShortLength,
        connectionType: ConnectionType.ble,
      );
    }
    final packetIndex = data[2];
    if (_partialData.containsKey(packetIndex)) {
      throw UnexpectedDataPacketException(
        reason: UnexpectedDataPacketReason.indexAlreadySet,
        connectionType: ConnectionType.ble,
      );
    }

    if (packetIndex == 0) {
      if (_expectedDataLength != -1) {
        throw UnexpectedDataPacketException(
          reason: UnexpectedDataPacketReason.dataLengthAlreadySet,
          connectionType: ConnectionType.ble,
        );
      }
      _expectedDataLength = data[4];
    }

    // for first packet, skip the first 5 bytes | for the rest, skip the first 3 bytes
    final noPrefixData = data.sublist(packetIndex == 0 ? 5 : 3);
    if (noPrefixData.isNotEmpty) {
      // I think for all requests we get a last empty packet with just the index
      // -- Not sure if this is always the case so I will ignore it for now
      _partialData[packetIndex] = noPrefixData;
    }
  }

  int get expectedDataLength => _expectedDataLength;

  int get currentDataLength =>
      _partialData.values.fold(0, (acc, e) => acc + e.length);

  bool get isComplete => currentDataLength == expectedDataLength;

  Uint8List get data {
    final data = _partialData.entries
        .sortedByCompare((e) => e.key, (a, b) => a.compareTo(b))
        .map((e) => e.value)
        .expand((e) => e)
        .toList();
    return Uint8List.fromList(data);
  }

  _Request(this.operation, this.transformer, this.completer);
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);
}
