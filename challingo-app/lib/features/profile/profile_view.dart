import '../../core/extensions/context_extension.dart';
import 'package:flutter/material.dart';
import 'presentation/profile_view_phone.dart';
import 'presentation/profile_view_tablet.dart';
import 'presentation/profile_view_desktop.dart';


class ProfileView extends StatelessWidget {
    const ProfileView({super.key});
    @override
    Widget build(BuildContext context) {
      if(context.isDesktop){
        return ProfileViewDesktop();
      }else if(context.isMyTablet){
        return ProfileViewTablet();
      }else{
        return ProfileViewPhone();
      }
    }
}

