import "dart:typed_data";

// ignore: one_member_abstracts
abstract class BlePacker {
  List<Uint8List> pack(Uint8List payload, int mtu);
}
