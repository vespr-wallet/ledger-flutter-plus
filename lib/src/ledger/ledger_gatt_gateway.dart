import 'dart:async';
import 'dart:collection';

import 'package:ledger_flutter/ledger_flutter.dart';

class LedgerGattGateway extends GattGateway {
  /// Ledger Nano X service id
  static const serviceId = '13D63400-2C97-0004-0000-4C6564676572';

  static const writeCharacteristicKey = '13D63400-2C97-0004-0002-4C6564676572';
  static const notifyCharacteristicKey = '13D63400-2C97-0004-0001-4C6564676572';

  final UniversalBle bleManager;
  final BlePacker _packer;
  final DiscoveredLedger ledger;
  final LedgerGattReader _gattReader;

  BleCharacteristic? characteristicWrite;
  BleCharacteristic? characteristicNotify;
  int _mtu;

  /// The map of request ids to pending requests.
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
    final supported = isRequiredServiceSupported();
    if (!supported) {
      throw LedgerException(message: 'Required service not supported');
    }

    _mtu = await UniversalBle.requestMtu(ledger.device.id, _mtu);

    await UniversalBle.setNotifiable(
      ledger.device.id,
      serviceId,
      notifyCharacteristicKey,
      BleInputProperty.notification,
    );

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
    final supported = isRequiredServiceSupported();
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
  bool isRequiredServiceSupported() {
    characteristicWrite = null;
    characteristicNotify = null;

    getService(UUID(serviceId))?.let((service) {
      characteristicWrite =
          getCharacteristic(service, UUID(writeCharacteristicKey));
      characteristicNotify =
          getCharacteristic(service, UUID(notifyCharacteristicKey));
    });

    return characteristicWrite != null && characteristicNotify != null;
  }

  @override
  void onServicesInvalidated() {
    characteristicWrite = null;
    characteristicNotify = null;
  }

  /// Get the MTU.
  /// The Maximum Transmission Unit (MTU) is the maximum length of an ATT packet.
  int get mtu => _mtu;

  @override
  BleService? getService(UUID service) {
    try {
      return ledger.services.firstWhere((s) => s.uuid == service.toString());
    } on StateError {
      return null;
    }
  }

  @override
  BleCharacteristic? getCharacteristic(
    BleService service,
    UUID characteristic,
  ) {
    try {
      return service.characteristics
          .firstWhere((c) => c.uuid == characteristic.toString());
    } on StateError {
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

/// A pending request to the server.
class _Request {
  /// The method that was sent.
  final LedgerOperation operation;

  /// The transformer that needs to be applied.
  final LedgerTransformer? transformer;

  /// The completer to use to complete the response future.
  final Completer completer;

  _Request(this.operation, this.transformer, this.completer);
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T that) op) => op(this);
}
