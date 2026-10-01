

import '/features/login/widgets/login_with_username_pass_widget.dart';

import '/widgets/app_lang_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../login_controller.dart';

class LoginViewPhone extends HookConsumerWidget {
  const LoginViewPhone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginController = ref.watch(loginControllerProvider);

    useEffect(() {
      loginController.checkUser();
      return null;
    }, []);

    return SafeArea(
      child: Scaffold(
        floatingActionButton: const Padding(
          padding: EdgeInsets.all(8.0),
          child: AppLangWidget(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        body: 
        
        const LoginWithUsernamePassWidget(),
        
      ),
    );
  }
}
