import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/challingo/challingo_widgets.dart';
import '../../widgets/challingo/tilo.dart';
import '../play/game_catalog.dart';
import 'email_code_sheet.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _busy = false;

  Future<void> _playNow() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).playAsGuest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.violet,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final g in [
                      GameKind.sudoku,
                      GameKind.pathLink,
                      GameKind.wordGuess,
                      GameKind.mineLogic,
                      GameKind.codeBreaker,
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GameGlyphTile(
                          g,
                          background: Colors.white.withValues(alpha: 0.16),
                          size: 48,
                        ).withGlyphColor(Colors.white),
                      ),
                  ],
                ),
                const Spacer(),
                const Tilo(
                  size: 190,
                  body: Colors.white,
                  face: AppColors.violet,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Challingo',
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 56,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ten puzzle games.\nA new race every four hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
                const Spacer(flex: 2),
                PillButton(
                  label: 'Play now',
                  style: PillStyle.light,
                  height: 60,
                  loading: _busy,
                  onPressed: _playNow,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      shape: const StadiumBorder(),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () => EmailCodeSheet.show(
                            context,
                            EmailCodePurpose.signIn,
                          ),
                    child: const Text('I have an account'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Playing as a guest? Add your email any time to keep your stars and streak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
