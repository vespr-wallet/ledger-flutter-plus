import 'dart:async';
import 'dart:collection';

extension CompleterWithTimeout<T> on Completer<T> {
  void setTimeout(Duration duration,
      {void Function()? onTimeout, T? returnOnTimeout}) {
    Future.delayed(duration).then((_) {
      if (!isCompleted) {
        if (returnOnTimeout != null) {
          complete(returnOnTimeout);
        } else {
          completeError(TimeoutException("Operation timed out", duration));
        }
        onTimeout?.call();
      }
    });
  }

  void completeIfPending(T value) {
    if (!isCompleted) {
      complete(value);
    }
  }

  void completeErrorIfPending(Object error) {
    if (!isCompleted) {
      completeError(error);
    }
  }
}

class RequestQueue {
  bool _disposed = false;

  final Completer<void> _isReady;

  /// Used to kill the message if it's taking too long to send/process
  final Duration? inFlightTimeout;

  final Queue<({FutureOr Function() data, Completer completer})> _requests =
      Queue();
  bool _isSending = false;

  RequestQueue({
    this.inFlightTimeout,
    Completer<void>? isReady,
  }) : _isReady = isReady ?? (Completer()..complete()) {
    _isReady.future.then((value) => _checkAndSendNext()).ignore();
  }

  Future<OUT> enqueueRequest<OUT>(FutureOr<OUT> Function() request) {
    if (_disposed) {
      throw StateError("RequestQueue disposed");
    }
    final Completer<OUT> completer = Completer();
    _requests.add((data: request, completer: completer));
    if (!_isSending) {
      _checkAndSendNext();
    }
    return completer.future;
  }

  Future<void> _checkAndSendNext() async {
    if (_isReady.isCompleted &&
        _requests.isNotEmpty &&
        !_isSending &&
        !_disposed) {
      await _sendNext();
    }
  }

  Future<void> _sendNext() async {
    try {
      if (_requests.isEmpty || _disposed) {
        _isSending = false;
        return;
      }
      _isSending = true;
      final (data: request, completer: completer) = _requests.removeFirst();

      try {
        final inFlightTimeout = this.inFlightTimeout;
        if (inFlightTimeout != null) {
          completer.setTimeout(inFlightTimeout);
        }

        final resultFuture = request();

        // Wait for either the future value to complete or the completer to complete
        // --- Note: The completer would complete before result only if it times out
        await Future.any([Future.value(resultFuture), completer.future]);

        completer.completeIfPending(await resultFuture);
      } catch (e) {
        completer.completeErrorIfPending(e);
      }
    } catch (e) {
      // ignore: avoid_print
      print("MessageQueue: Error fetching request with queue removeFirst");
    }
    await _sendNext();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    try {
      _disposed = true;
      _isSending = false;

      _isReady.completeErrorIfPending(
        StateError("RequestQueue disposed"),
      );
      while (_requests.isNotEmpty) {
        final req = _requests.removeFirst();

        req.completer.completeErrorIfPending(
          StateError("Pending Request Canceled | RequestQueue disposed"),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print("MessageQueue: Error disposing request queue $e");
    }
  }
}
