import 'package:ledger_flutter_plus/src/operations/ledger_operations.dart';

@Deprecated('Use [LedgerSimpleOperation] or [LedgerComplexOperation] instead')
abstract class LedgerOperation<T> extends LedgerRawOperation<T> {}
