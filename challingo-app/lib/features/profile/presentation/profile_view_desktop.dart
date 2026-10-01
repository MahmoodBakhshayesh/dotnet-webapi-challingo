import 'package:flutter/material.dart';
import '../profile_controller.dart';
import '../../../core/extensions/context_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfileViewDesktop extends ConsumerWidget {
  const ProfileViewDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(profileControllerProvider);
    return Scaffold(
      appBar: ProfileAppBarDesktop(),
      body: Column(children: []),
    );
  }
}

class ProfileAppBarDesktop extends StatelessWidget implements PreferredSizeWidget {
  const ProfileAppBarDesktop({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(108);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: context.mainColor,
      alignment: Alignment.center,
      child: const SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      Spacer(),
                      SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
