import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/competition_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../boards/board_widgets.dart';
import '../competition/competition_providers.dart';

/// Groups tab: your groups, start one, join with a code or link.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.violet,
          onRefresh: () async => ref.invalidate(groupsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text('Groups', style: Theme.of(context).textTheme.headlineSmall),
              Text('Friends, family, the office: share a link and compare every round.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: PillButton(label: 'New group', height: 52, onPressed: () => _create(context, ref))),
                const SizedBox(width: 12),
                Expanded(child: PillButton(label: 'Join', height: 52, style: PillStyle.secondary, onPressed: () => _join(context, ref))),
              ]),
              const SizedBox(height: 20),
              ...switch (groups) {
                AsyncData(:final value) when value.isEmpty => [
                  const SizedBox(height: 24),
                  const Center(child: Tilo(size: 110, mood: TiloMood.hello)),
                  const SizedBox(height: 12),
                  Text('No groups yet. Start one and send the link to your friends.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                ],
                AsyncData(:final value) => [
                  for (final g in value) ...[
                    ChallingoCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      onTap: () => context.push('/groups/${g.groupId}'),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(13)),
                          child: Text(g.name.characters.first.toUpperCase(), style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.coral)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${g.memberCount} ${g.memberCount == 1 ? 'member' : 'members'}${g.isOwner ? ' · you started it' : ''}', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                AsyncError(:final error) => [Text('$error', textAlign: TextAlign.center)],
                _ => [const Center(child: CircularProgressIndicator(color: AppColors.violet))],
              },
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _ask(context, title: 'New group', hint: 'Office League', action: 'Create');
    if (name == null || !context.mounted) return;
    await _guard(context, () async {
      final group = await ref.read(challingoApiProvider).createGroup(name);
      ref.invalidate(groupsProvider);
      if (context.mounted) await context.push('/groups/${group.groupId}');
    });
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await _ask(context, title: 'Join a group', hint: 'Invite code or link', action: 'Join');
    if (code == null || !context.mounted) return;
    await _guard(context, () async {
      final group = await ref.read(challingoApiProvider).joinGroup(code);
      ref.invalidate(groupsProvider);
      if (context.mounted) await context.push('/groups/${group.groupId}');
    });
  }
}

Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating));
    }
  }
}

Future<String?> _ask(BuildContext context, {required String title, required String hint, required String action}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        decoration: InputDecoration(hintText: hint, counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// A group: invite link, this week's group board, members, leave.
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    final weekKey = ref.watch(todayProvider).value?.weekKey;
    return Scaffold(
      body: SafeArea(
        child: switch (detail) {
          AsyncData(value: final d) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(children: [
                SquareIconButton(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go('/groups')),
                const SizedBox(width: 12),
                Expanded(child: Text(d.group.name, style: Theme.of(context).textTheme.titleLarge)),
              ]),
              const SizedBox(height: 16),
              ChallingoCard(
                color: AppColors.violet,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('INVITE FRIENDS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  SelectableText(d.group.inviteCode, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 30, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  PillButton(
                    label: 'Copy invite link',
                    height: 48,
                    style: PillStyle.secondary,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: d.group.inviteUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite link copied'), behavior: SnackBarBehavior.floating));
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Text('THIS WEEK', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 10),
              if (weekKey != null)
                BoardList(
                  shrinkWrap: true,
                  request: (period: BoardPeriod.week, key: weekKey, scope: BoardScope.group, groupId: groupId),
                  emptyText: 'Nobody in the group has points this week yet.',
                ),
              const SizedBox(height: 16),
              Text('MEMBERS · ${d.members.length}', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 10),
              for (final m in d.members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Text(flagOf(m.countryCode), style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m.isMe ? '${m.displayName} (you)' : m.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (m.isOwner) Text('owner', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _leave(context, ref, d.group),
                child: const Text('Leave group', style: TextStyle(color: AppColors.berry, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          AsyncError(:final error) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$error', textAlign: TextAlign.center))),
          _ => const Center(child: CircularProgressIndicator(color: AppColors.violet)),
        },
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, GroupInfo group) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Leave ${group.name}?'),
        content: const Text('You can join again with the invite link.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.berry), onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await _guard(context, () async {
      await ref.read(challingoApiProvider).leaveGroup(group.groupId);
      ref.invalidate(groupsProvider);
      if (context.mounted) context.go('/groups');
    });
  }
}

/// Opened from an invite link (`/g/CODE`): shows the group and joins it.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  late final Future<GroupInvite> _invite = ref.read(challingoApiProvider).previewInvite(widget.code);
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    await _guard(context, () async {
      final group = await ref.read(challingoApiProvider).joinGroup(widget.code);
      ref.invalidate(groupsProvider);
      if (mounted) context.go('/groups/${group.groupId}');
    });
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder(
          future: _invite,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Tilo(size: 110, mood: TiloMood.thinking),
                  const SizedBox(height: 12),
                  Text('${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  PillButton(label: 'Back to home', onPressed: () => context.go('/home')),
                ]),
              );
            }
            final invite = snap.data;
            if (invite == null) return const Center(child: CircularProgressIndicator(color: AppColors.violet));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              const Center(child: Tilo(size: 130, mood: TiloMood.cheering)),
              const SizedBox(height: 16),
              Text("You're invited to", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              Text(invite.name, textAlign: TextAlign.center, style: const TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 34)),
              Text('${invite.memberCount} ${invite.memberCount == 1 ? 'member' : 'members'}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              PillButton(label: invite.alreadyMember ? 'Open group' : 'Join group', loading: _joining, onPressed: _join),
              const SizedBox(height: 12),
              PillButton(label: 'Not now', style: PillStyle.secondary, onPressed: () => context.go('/home')),
            ]);
          },
        ),
      ),
    ),
  );
}
