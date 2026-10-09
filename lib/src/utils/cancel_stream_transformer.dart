import "dart:async";

extension CancelStreamTransformerExtension<T> on Stream<T> {
  Stream<T> onCancel(FutureOr<void> Function() onCancel) {
    return transform(OnCancelStreamTransformer(onCancel));
  }
}

class OnCancelStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final FutureOr<void> Function() onCancel;

  OnCancelStreamTransformer(this.onCancel);

  @override
  Stream<T> bind(Stream<T> stream) {
    final controller = StreamController<T>();

    late final StreamSubscription<T>? subscription;

    controller.onListen = () {
      subscription = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    };

    controller.onCancel = () {
      // Nobody can listen to these futures anymore (the stream was cancelled), so `ignore()` them to avoid their
      // errors (e.g. failing to stop the BLE scan) being reported as uncaught.
      final onCancelResult = onCancel();
      if (onCancelResult is Future<void>) {
        onCancelResult.ignore();
      }
      subscription?.cancel().ignore();
    };

    return controller.stream;
  }
}
