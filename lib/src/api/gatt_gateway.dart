import "../../ledger_flutter_plus.dart";
import "../operations/ledger_operations.dart";

/// GATT is an acronym for the Generic ATTribute Profile, and it defines
/// the way that two Bluetooth Low Energy devices transfer data back and forth
/// using concepts called Services and Characteristics.
///
/// It makes use of a generic data protocol called the Attribute Protocol (ATT),
/// which is used to store Services, Characteristics and related data in a
/// simple lookup table using 16-bit IDs for each entry in the table.
///
/// a BLE peripheral can only be connected to one central device at a time!
///
/// Ledger/peripheral = GATT server
/// Phone = GATT client
abstract class GattGateway {
  Future<void> start();

  Future<void> disconnect();

  Future<bool> isRequiredServiceSupported();

  void onServicesInvalidated();

  Future<T> sendOperation<T>(
    LedgerRawOperation<T> operation, {
    LedgerTransformer? transformer,
  });

  Future<BleService?> getService(String serviceId);

  Future<BleCharacteristic?> getCharacteristic(
    BleService service,
    String characteristic,
  );

  Future<void> close();
}
