import 'dart:async';

class SuccessNotice {
  final String message;

  const SuccessNotice({required this.message});

  @override
  String toString() => message;
}

/// Global success message bus — mirror of [FailureBus] for positive feedback
/// (saved, deleted, copied, ...). Listened to by `GlobalSuccessListener`.
class SuccessBus {
  SuccessBus._();

  static final SuccessBus I = SuccessBus._();

  final _ctrl = StreamController<SuccessNotice>.broadcast();

  Stream<SuccessNotice> get stream => _ctrl.stream;

  void emit(SuccessNotice notice) => _enqueue(notice);

  void emitMsg(String message) => emit(SuccessNotice(message: message));

  void _enqueue(SuccessNotice notice) {
    if (_ctrl.isClosed) return;
    scheduleMicrotask(() {
      if (_ctrl.isClosed) return;
      _ctrl.add(notice);
    });
  }

  void dispose() => _ctrl.close();
}
