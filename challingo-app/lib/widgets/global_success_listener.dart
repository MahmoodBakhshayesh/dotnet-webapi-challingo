import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/helpers/success_presenter.dart';
import '../core/interfaces/base_success.dart';

/// App-root wrapper that subscribes to [SuccessBus] and surfaces every
/// [SuccessNotice] through [SuccessPresenter].
///
/// Counterpart of [GlobalFailureListener] for positive feedback
/// ("saved", "deleted", …).
class GlobalSuccessListener extends StatefulWidget {
  final Widget child;

  const GlobalSuccessListener({super.key, required this.child});

  @override
  State<GlobalSuccessListener> createState() => _GlobalSuccessListenerState();
}

class _GlobalSuccessListenerState extends State<GlobalSuccessListener> {
  StreamSubscription<SuccessNotice>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SuccessBus.I.stream.listen(SuccessPresenter.show, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
