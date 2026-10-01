import 'package:flutter/material.dart';
import '../../login/domain/entities/login_response.dart';
import '../../login/login_view_state.dart';
import '../../profile/widgets/user_avatar.dart';
import '../home_controller.dart';
import '../../../core/extensions/context_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeViewPhone extends ConsumerWidget {
  const HomeViewPhone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeControllerProvider);

    return Scaffold(
      appBar: HomeAppBar(),
      body: Column(
        children: [

        ],
      ),
    );
  }
}

class HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HomeController homeController = ref.watch(homeControllerProvider);
    UserEntity user = ref.watch(authenticatedUserProvider)!;
    return Container(
      height: preferredSize.height,
      color: context.mainColor,
      alignment: Alignment.center,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          homeController.goProfile(context);
                        },
                        child: UserAvatar(
                          key: Key(user.profileImageUrl??'-'),
                          url: user.profileImageUrl,
                          size: 68,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        user.fullName,
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
