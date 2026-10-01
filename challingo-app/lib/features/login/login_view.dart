import 'package:flutter/material.dart';
import '../../core/extensions/context_extension.dart';
import 'presentation/login_view_desktop.dart';
import 'presentation/login_view_tablet.dart';
import 'presentation/login_view_phone.dart';
class LoginView extends StatelessWidget {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    if(context.isDesktop){
      return LoginViewDesktop();
    }else if(context.isMyTablet){
      return LoginViewTablet();
    }else{
      return LoginViewPhone();
    }
  }
}