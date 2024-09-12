enum LedgerBleDeviceInfo {
  nanoX(
    serviceId: '13D63400-2C97-0004-0000-4C6564676572',
    writeCharacteristicKey: '13D63400-2C97-0004-0002-4C6564676572',
    notifyCharacteristicKey: '13D63400-2C97-0004-0001-4C6564676572',
  ),
  stax(
    serviceId: '13D63400-2C97-6004-0000-4C6564676572',
    writeCharacteristicKey: '13d63400-2c97-6004-0002-4c6564676572',
    notifyCharacteristicKey: '13D63400-2C97-6004-0001-4C6564676572',
  ),
  flex(
    serviceId: '13D63400-2C97-3004-0000-4C6564676572',
    writeCharacteristicKey: '13d63400-2c97-3004-0002-4c6564676572',
    notifyCharacteristicKey: '13D63400-2C97-3004-0001-4C6564676572',
  );

  const LedgerBleDeviceInfo({
    required this.serviceId,
    required this.writeCharacteristicKey,
    required this.notifyCharacteristicKey,
  });

  final String serviceId;
  final String writeCharacteristicKey;
  final String notifyCharacteristicKey;
}
