import '../../core/extensions/context_extension.dart';
import 'package:flutter/material.dart';
import 'presentation/home_view_phone.dart';
import 'presentation/home_view_tablet.dart';
import 'presentation/home_view_desktop.dart';


class HomeView extends StatelessWidget {
    const HomeView({super.key});
    @override
    Widget build(BuildContext context) {
      if(context.isDesktop){
        return HomeViewDesktop();
      }else if(context.isMyTablet){
        return HomeViewTablet();
      }else{
        return HomeViewPhone();
      }
    }
}

