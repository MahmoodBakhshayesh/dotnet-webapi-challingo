import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';

/// Shown while the saved session is restored; offers a retry when the server can't be reached.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.violet,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Tilo(size: 150, body: Colors.white, face: AppColors.violet),
              const SizedBox(height: 24),
              if (session.hasError) ...[
                Text(
                  session.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  child: PillButton(
                    label: 'Try again',
                    style: PillStyle.light,
                    height: 52,
                    onPressed: () => ref.invalidate(sessionProvider),
                  ),
                ),
              ] else
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
