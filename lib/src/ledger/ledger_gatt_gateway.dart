import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:ledger_flutter/ledger_flutter.dart';

class LedgerGattGateway extends GattGateway {
  static const serviceId = '13d63400-2c97-0004-0000-4c6564676572';
  static const serviceIdWithSuffix = '13d63400-2c97-0004-0000-4c6564676572-0x134090e4470';

  static const writeCharacteristicKey = '13D63400-2C97-0004-0002-4C6564676572';
  static const notifyCharacteristicKey = '13D63400-2C97-0004-0001-4C6564676572';

  final UniversalBle bleManager;
  final BlePacker _packer;
  final DiscoveredLedger ledger;
  final LedgerGattReader _gattReader;

  BleCharacteristic? characteristicWrite;
  BleCharacteristic? characteristicNotify;
  int _mtu;

  final _pendingOperations = ListQueue<_Request>();
  final Function? _onError;

  LedgerGattGateway({
    required this.bleManager,
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
        throw LedgerException(
            message: 'Required service not supported. '
                'Write characteristic: ${characteristicWrite != null}, '
                'Notify characteristic: ${characteristicNotify != null}');
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

      try {
        if (characteristicNotify != null && 
            characteristicNotify!.properties.contains(CharacteristicProperty.notify)) {
          await UniversalBle.setNotifiable(
            ledger.device.id,
            serviceId,
            notifyCharacteristicKey,
            BleInputProperty.notification,
          );
        } else {
          throw Exception('Notify characteristic does not support notifications');
        }
      } catch (e) {
        throw LedgerException(message: 'Failed to set notifiable: $e');
      }

      UniversalBle.onValueChange = (deviceId, characteristicId, data) async {
        if (_pendingOperations.isEmpty) {
          return;
        }

        try {
          final request = _pendingOperations.first;
          final transformer = request.transformer;
          final reader = ByteDataReader();
          if (transformer != null) {
            final transformed = await transformer.onTransform([data]);
            reader.add(stripApduHeader(transformed));
          } else {
            reader.add(stripApduHeader(data));
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
    LedgerOperation operation, {
    LedgerTransformer? transformer,
  }) async {
    final supported = await isRequiredServiceSupported();
    if (!supported) {
      throw LedgerException(message: 'Required service not supported');
    }

    final writer = ByteDataWriter();
    final output = await operation.write(writer);
    for (var payload in output) {
      final packets = _packer.pack(payload, _mtu);

      for (var packet in packets) {
        await UniversalBle.writeValue(
          ledger.device.id,
          serviceId,
          characteristicWrite!.uuid,
          packet,
          BleOutputProperty.withResponse,
        );
      }
    }

    var completer = Completer<T>.sync();
    _pendingOperations.addFirst(_Request(operation, transformer, completer));

    return completer.future;
  }

  @override
  Future<bool> isRequiredServiceSupported() async {
    characteristicWrite = null;
    characteristicNotify = null;

    try {
      final service = await getService(UUID(serviceId));
      if (service != null) {
        characteristicWrite = await getCharacteristic(service, UUID(writeCharacteristicKey));
        characteristicNotify = await getCharacteristic(service, UUID(notifyCharacteristicKey));
      }
    } catch (e) {
      // Error handling
    }

    final isSupported =
        characteristicWrite != null &&
        characteristicNotify != null &&
        characteristicWrite!.properties.contains(CharacteristicProperty.write) &&
        characteristicNotify!.properties.contains(CharacteristicProperty.notify);
    return isSupported;
  }

  @override
  Future<BleCharacteristic?> getCharacteristic(
    BleService service,
    UUID characteristic,
  ) async {
    try {
      final targetUuid = characteristic.toString().toLowerCase();
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
  Future<BleService?> getService(UUID service) async {
    try {
      final services = await UniversalBle.discoverServices(ledger.device.id);
      
      final targetUuid = service.toString().toLowerCase();
      final targetUuidWithSuffix = serviceIdWithSuffix.toLowerCase();
      
      final foundService = services.firstWhere(
        (s) => s.uuid.toLowerCase() == targetUuid || s.uuid.toLowerCase() == targetUuidWithSuffix,
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
  final LedgerOperation operation;
  final LedgerTransformer? transformer;
  final Completer completer;

  _Request(this.operation, this.transformer, this.completer);
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);
}

Uint8List stripApduHeader(Uint8List data) {
  if (data.length > 5) {
    return data.sublist(5);
  }
  return data;
}