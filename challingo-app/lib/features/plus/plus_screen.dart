import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/monetization/purchases_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../competition/monetization_providers.dart';

final _packagesProvider = FutureProvider.autoDispose.family<List<Package>, String>(
  (ref, userId) => PurchasesService.instance.packages(userId),
);

/// Plus: what it gives, the store's packages and prices, restore, and the active state.
class PlusScreen extends ConsumerStatefulWidget {
  const PlusScreen({super.key});

  @override
  ConsumerState<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends ConsumerState<PlusScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(monetizationProvider).value;
    final text = Theme.of(context).textTheme;
    final active = status?.plusActive ?? false;
    final packages = status == null ? null : ref.watch(_packagesProvider(status.rewardUserId));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(children: [
              SquareIconButton(icon: Icons.close_rounded, label: 'Close', onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(colors: [AppColors.violet, AppColors.violetDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(children: [
                const Tilo(size: 90, mood: TiloMood.cheering, body: Colors.white, face: AppColors.violet),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Challingo Plus', style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 30, color: Colors.white)),
                    Text(
                      active
                          ? 'You are Plus${status?.plusExpiresAtUtc == null ? '' : ' until ${_date(status!.plusExpiresAtUtc!)}'}. Thank you!'
                          : 'Play every run, every game, every day.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            ChallingoCard(
              child: Column(children: [
                for (final (icon, title, body) in const [
                  (Icons.all_inclusive_rounded, 'Unlimited ranked runs', 'No daily limit: join every run of every game.'),
                  (Icons.leaderboard_rounded, 'Climb faster', 'Every run adds to your day, week and month boards.'),
                  (Icons.favorite_rounded, 'Support Challingo', 'Keeps new games and puzzles coming.'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.lilac, borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: AppColors.violet),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(body, style: text.bodySmall),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            if (!active) ...switch (packages) {
              AsyncData(value: final list) when list.isNotEmpty => [
                for (final p in list) ...[
                  PillButton(
                    label: '${_packageName(p)} · ${p.storeProduct.priceString}',
                    loading: _busy,
                    onPressed: () => _run(() async {
                      if (await PurchasesService.instance.buy(status!.rewardUserId, p)) {
                        await ref.read(monetizationProvider.notifier).syncPlus();
                      }
                    }),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              AsyncLoading() => [const Center(child: CircularProgressIndicator(color: AppColors.violet))],
              _ => [
                ChallingoCard(
                  color: AppColors.sunSoft,
                  child: Text(
                    PurchasesService.instance.available
                        ? 'Plus is not available in your store yet. Please try again later.'
                        : 'The store is not connected in this build yet.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            },
            if (PurchasesService.instance.available)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await PurchasesService.instance.restore(status!.rewardUserId);
                        await ref.read(monetizationProvider.notifier).syncPlus();
                      }),
                child: const Text('Restore purchases', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            if (status?.devRewards ?? false) ...[
              const SizedBox(height: 8),
              PillButton(
                label: active ? 'Test: end Plus' : 'Test: Plus for 30 days',
                style: PillStyle.secondary,
                height: 48,
                onPressed: _busy ? null : () => _run(() => ref.read(monetizationProvider.notifier).devPlus(active ? 0 : 30)),
              ),
              const SizedBox(height: 4),
              Text('Development build: no store involved.', textAlign: TextAlign.center, style: text.bodySmall),
            ],
            const SizedBox(height: 12),
            Text(
              'Subscriptions renew automatically until cancelled. Manage or cancel any time in your App Store or Google Play account settings.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _packageName(Package p) => switch (p.packageType) {
    PackageType.monthly => 'Monthly',
    PackageType.annual => 'Yearly',
    PackageType.weekly => 'Weekly',
    PackageType.lifetime => 'Lifetime',
    _ => p.storeProduct.title,
  };
}
