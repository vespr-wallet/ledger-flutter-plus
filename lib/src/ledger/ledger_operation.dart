import 'dart:typed_data';

import 'package:ledger_flutter_plus/src/utils/buffer.dart';

abstract class LedgerOperation<T> {
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
