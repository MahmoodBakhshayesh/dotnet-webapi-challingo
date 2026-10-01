import '/features/login/login_controller.dart';
import '/features/login/login_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/extensions/context_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_styles.dart';
import '../../../widgets/buttons/app_new_button.dart';
import 'package:challingo/widgets/inputs/challingo_field_decoration.dart';
import '../../../widgets/main_card.dart';
import '../domain/entities/offline_test_login.dart';

/// Default login screen — username and password (no phone/OTP steps).
class LoginWithUsernamePassWidget extends HookConsumerWidget {
  const LoginWithUsernamePassWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginController = ref.watch(loginControllerProvider);
    final usernameC = useTextEditingController(
      text: OfflineTestLogin.enabled ? OfflineTestLogin.username : '',
    );
    final passC = useTextEditingController(
      text: OfflineTestLogin.enabled ? OfflineTestLogin.password : '',
    );
    final error = ref.watch(loginErrorMessageProvider);
    final isLoading = ref.watch(loginIsLoadingProvider);

    useListenable(usernameC);
    useListenable(passC);

    final canSubmit = usernameC.text.trim().isNotEmpty &&
        passC.text.isNotEmpty &&
        !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.localizations.welcomeTitle,
                style: AppStyles.pageHeader,
              ),
              Text(
                context.localizations.enterUsernameAndPassword,
                style: AppStyles.pageBody,
              ),
            ],
          ),
        ),
        MainCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.localizations.username,
                style: AppStyles.cardHeader,
              ),
              const SizedBox(height: 8),
              ChallingoFieldDecoration.textField(
                placeholder: context.localizations.username,
                controller: usernameC,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Text(
                context.localizations.password,
                style: AppStyles.cardHeader,
              ),
              const SizedBox(height: 8),
              ChallingoFieldDecoration.textField(
                isPassword: true,
                controller: passC,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
              ),
              if (error != null && error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: const TextStyle(color: AppColors.errorColor, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.0),
          child: AppNewButton(
            label: context.localizations.login,
            onPressed: canSubmit
                ? () => loginController.login(usernameC.text.trim(), passC.text)
                : null,
            disabled: !canSubmit,
            icon: Icons.login,
            color: AppColors.actions,
          ),
        ),
      ],
    );
  }
}
