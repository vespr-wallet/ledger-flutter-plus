import 'dart:async';

extension CancelStreamTransformerExtension<T> on Stream<T> {
  Stream<T> onCancel(void Function() onCancel) {
    return transform(OnCancelStreamTransformer(onCancel));
  }
}

class OnCancelStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final void Function() onCancel;

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
      onCancel();
      subscription?.cancel();
    };

    return controller.stream;
  }
}
