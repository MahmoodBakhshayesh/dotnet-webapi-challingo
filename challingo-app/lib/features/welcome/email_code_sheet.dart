import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';

enum EmailCodePurpose { signIn, linkGuest }

/// Two steps — email, then the 6-digit code — for signing in/up or attaching an email to a guest.
class EmailCodeSheet extends ConsumerStatefulWidget {
  const EmailCodeSheet({super.key, required this.purpose});

  final EmailCodePurpose purpose;

  static Future<bool?> show(BuildContext context, EmailCodePurpose purpose) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => EmailCodeSheet(purpose: purpose),
  );

  @override
  ConsumerState<EmailCodeSheet> createState() => _EmailCodeSheetState();
}

class _EmailCodeSheetState extends ConsumerState<EmailCodeSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _isNewAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final email = _email.text.trim();
    if (!email.contains('@')) throw 'Enter a valid email address.';
    final session = ref.read(sessionProvider.notifier);
    if (widget.purpose == EmailCodePurpose.linkGuest) {
      await session.requestEmailLink(email);
    } else {
      _isNewAccount = await session.requestEmailCode(email);
    }
    setState(() => _codeSent = true);
  });

  Future<void> _verify() => _run(() async {
    final session = ref.read(sessionProvider.notifier);
    final email = _email.text.trim(), code = _code.text.trim();
    if (widget.purpose == EmailCodePurpose.linkGuest) {
      await session.confirmEmailLink(email, code);
    } else {
      await session.verifyEmailCode(email, code, isNewAccount: _isNewAccount);
    }
    if (mounted) Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = widget.purpose == EmailCodePurpose.linkGuest ? 'Keep your progress' : 'Sign in with email';
    final subtitle = _codeSent
        ? 'We sent a code to ${_email.text.trim()}.'
        : widget.purpose == EmailCodePurpose.linkGuest
        ? 'Add an email so your stars, streak and history are safe on any phone.'
        : "We'll email you a sign-in code. No password needed.";

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(9)))),
          const SizedBox(height: 18),
          Text(title, style: text.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: 20),
          if (!_codeSent)
            _field(_email, label: 'Email', keyboard: TextInputType.emailAddress, autofill: AutofillHints.email, onDone: _sendCode)
          else
            _field(_code, label: 'Code', keyboard: TextInputType.number, autofill: AutofillHints.oneTimeCode, onDone: _verify),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.berry, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 20),
          PillButton(label: _codeSent ? 'Continue' : 'Send code', loading: _busy, onPressed: _codeSent ? _verify : _sendCode),
          if (_codeSent)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSent = false),
              child: const Text('Use a different email', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.violet)),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, {required String label, required TextInputType keyboard, required String autofill, required VoidCallback onDone}) =>
      TextField(
        controller: c,
        autofocus: true,
        keyboardType: keyboard,
        autofillHints: [autofill],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.cloud,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.violet, width: 2)),
        ),
      );
}
