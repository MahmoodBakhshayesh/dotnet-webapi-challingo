import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../competition/monetization_providers.dart';

/// Watches a rewarded ad and reports the outcome. Returns true when a run was added.
Future<bool> watchAdForRun(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)), behavior: SnackBarBehavior.floating));
  try {
    final ok = await ref.read(monetizationProvider.notifier).watchAd();
    say(ok ? '+1 run and stars added. Have fun!' : 'Watch the whole ad to get the reward.');
    return ok;
  } catch (e) {
    say('$e');
    return false;
  }
}

/// Bottom sheet when today's runs are used: watch an ad or go Plus.
class RunUnlockSheet extends ConsumerStatefulWidget {
  const RunUnlockSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    // Above the bottom bar, not inside the tab.
    useRootNavigator: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const RunUnlockSheet(),
  );

  @override
  ConsumerState<RunUnlockSheet> createState() => _RunUnlockSheetState();
}

class _RunUnlockSheetState extends ConsumerState<RunUnlockSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(monetizationProvider).value;
    final adsLeft = status?.adsLeft ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('More runs today', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 26)),
          const SizedBox(height: 4),
          Text("You've played today's free runs.", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          PillButton(
            label: adsLeft > 0 ? 'Watch an ad: +1 run, +${status?.starsPerAd ?? 5} ★' : 'No more ads today',
            loading: _busy,
            onPressed: adsLeft == 0
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    setState(() => _busy = true);
                    final ok = await watchAdForRun(context, ref);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (ok) navigator.pop();
                  },
          ),
          const SizedBox(height: 6),
          Text('$adsLeft of ${status?.adsPerDay ?? 3} ads left today', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          PillButton(
            label: 'Go Plus: unlimited runs',
            style: PillStyle.secondary,
            onPressed: () {
              Navigator.pop(context);
              context.push('/plus');
            },
          ),
        ]),
      ),
    );
  }
}

/// Small "Plus" badge.
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(999)),
    child: const Text('PLUS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1, color: Colors.white)),
  );
}
