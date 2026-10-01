import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../competition/monetization_providers.dart';
import '../welcome/email_code_sheet.dart';

/// Name, time zone / country, email upgrade and sign-out.
class ProfileSheet extends ConsumerStatefulWidget {
  const ProfileSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    // Above the bottom bar, not inside the tab.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const ProfileSheet(),
  );

  @override
  ConsumerState<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<ProfileSheet> {
  late final _name = TextEditingController(text: ref.read(sessionProvider).value?.displayName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(challingoApiProvider).setDisplayName(_name.text.trim());
      await ref.read(sessionProvider.notifier).reload();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).value;
    if (me == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Your profile', style: text.headlineSmall),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          maxLength: 20,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          decoration: InputDecoration(
            labelText: 'Display name',
            filled: true,
            fillColor: AppColors.cloud,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.berry, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _InfoRow(label: 'Time zone', value: me.timeZoneId),
        _InfoRow(label: 'Country board', value: me.countryCode ?? 'None'),
        _InfoRow(label: 'Email', value: me.email ?? 'Not added (guest)'),
        const SizedBox(height: 16),
        PillButton(label: 'Save', loading: _saving, onPressed: _save),
        const SizedBox(height: 12),
        PillButton(
          label: (ref.watch(monetizationProvider).value?.plusActive ?? false) ? 'Plus: active' : 'Challingo Plus',
          style: PillStyle.secondary,
          onPressed: () {
            Navigator.pop(context);
            context.push('/plus');
          },
        ),
        const SizedBox(height: 12),
        if (me.isGuest)
          PillButton(label: 'Add email', style: PillStyle.secondary, onPressed: () => EmailCodeSheet.show(context, EmailCodePurpose.linkGuest))
        else
          PillButton(
            label: 'Sign out',
            style: PillStyle.secondary,
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(sessionProvider.notifier).signOut();
            },
          ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
    ]),
  );
}
