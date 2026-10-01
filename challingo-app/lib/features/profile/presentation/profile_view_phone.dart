import '/features/login/domain/entities/login_response.dart';
import '/features/login/login_view_state.dart';
import '/features/profile/widgets/user_avatar.dart';
import '/widgets/app_lang_widget.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import '/widgets/dot_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../widgets/buttons/app_button.dart';
import '../profile_controller.dart';
import '../../../core/extensions/context_extension.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfileViewPhone extends HookConsumerWidget {
  const ProfileViewPhone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileController = ref.watch(profileControllerProvider);
    final UserEntity? user = ref.watch(authenticatedUserProvider);

    final editMode = useState(false);
    if (user == null) {
      return Scaffold();
    }
    final nameC = useTextEditingController.fromValue(TextEditingValue(text: user.fullName));
    final usernameC = useTextEditingController.fromValue(TextEditingValue(text: user.username ?? ''));
    final emailC = useTextEditingController.fromValue(TextEditingValue(text: user.email ?? ''));

    return Scaffold(
      appBar: ProfileAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            UserAvatar(
              url: user.profileImageUrl,
              size: context.width * 0.4,
              onChange: profileController.setAvatar,
            ),
            ListTile(
              title: Text(user.phoneNumber),
              leading: const Icon(Icons.phone),
            ),
            editMode.value
                ? Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ChallingoFieldDecoration.textField(
                            label: context.localizations.name,
                            controller: nameC,
                          ),
                          ChallingoFieldDecoration.textField(
                            label: context.localizations.username,
                            controller: usernameC,
                          ),
                          ChallingoFieldDecoration.textField(
                            label: context.localizations.email,
                            controller: emailC,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                  )
                : Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(user.fullName),
                          leading: const Icon(Icons.person),
                        ),
                        if (user.username != null && user.username!.isNotEmpty)
                          ListTile(
                            title: Text(user.username!),
                            leading: const Icon(Icons.account_circle),
                          ),
                        if (user.email != null && user.email!.isNotEmpty)
                          ListTile(
                            title: Text(user.email!),
                            leading: const Icon(Icons.email),
                          ),
                      ],
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
              child: !editMode.value
                  ? Row(
                      spacing: 8,
                      children: [
                        DotButton(
                          size: 40,
                          icon: Icons.edit,
                          onPressed: () {
                            editMode.value = true;
                          },
                        ),
                        Expanded(
                          child: AppButton(
                            label: context.localizations.logout,
                            onPressed: () {},
                            onLongPress: () async {
                              await profileController.logout(context);
                            },
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: context.localizations.confirm,
                            onPressed: () async {
                              final update = await profileController.updateProfile(
                                fullName: nameC.text,
                                username: usernameC.text.trim().isEmpty ? null : usernameC.text.trim(),
                                email: emailC.text.trim().isEmpty ? null : emailC.text.trim(),
                              );
                              if (update) {
                                editMode.value = false;
                              }
                            },
                          ),
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

class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(108);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: context.mainColor,
      alignment: Alignment.center,
      child: SafeArea(
        child: Row(
          children: [
            const BackButton(
              color: Colors.white,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          context.localizations.profile,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      const AppLangWidget(),
                      const SizedBox(width: 8),
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
