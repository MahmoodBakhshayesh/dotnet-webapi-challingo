import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/profile/profile_state.dart';

/// Language toggle button: switches the app locale between `en` and `fa`
/// through `localizationProvider`.
class AppLangWidget extends HookConsumerWidget {
  const AppLangWidget({super.key});
  @override
  Widget build(BuildContext context ,WidgetRef ref) {
      final current = ref.watch(localizationProvider);
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8)
        ),
        child: TextButton.icon(
          icon: Icon(Icons.language),
          onPressed: (){
            var next = 'en';
            if(current.languageCode == 'en'){
              next = 'fa';
            }
            ref.read(localizationProvider.notifier).update((s)=>Locale(next));
          },
          label:   Text(current.languageCode)
        ),
      );
    }
  }
