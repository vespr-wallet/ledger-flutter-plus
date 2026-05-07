import "dart:typed_data";

import "../../ledger_flutter_plus_dart.dart";

sealed class LedgerOperation<T> {
  const LedgerOperation();
}

abstract class LedgerRawOperation<T> extends LedgerOperation<T> {
  /// The Packet sequence index describes the current sequence for fragmented
  /// payloads.
  /// The first fragment index is 0x00 and increased in following packets.
  Future<List<Uint8List>> write(ByteDataWriter writer);

  /// The Packet sequence index describes the current sequence for fragmented
  /// payloads.
  /// The first fragment index is 0x00 and increased in following packets.
  Future<T> read(ByteDataReader reader);

  Uint8List stripApduHeader(Uint8List data) {
    if (data.length > 5) {
      return data.sublist(5);
    }
    return data;
  }
}

abstract class LedgerComplexOperation<T> extends LedgerOperation<T> {
  const LedgerComplexOperation();

  Future<T> invoke(LedgerSendFct send);
}

typedef LedgerSendFct = Future<Y> Function<Y>(LedgerRawOperation<Y> operation);
