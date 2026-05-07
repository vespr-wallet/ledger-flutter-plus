import "dart:typed_data";

// ignore: one_member_abstracts
abstract class LedgerTransformer {
  const LedgerTransformer();

  Future<Uint8List> onTransform(List<Uint8List> transform);
}
