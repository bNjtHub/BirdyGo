/// Settings > « Mon oiseau » (J6i): the onboarding's bird step, opened from
/// the Settings row, with a back arrow instead of the step counter. The
/// picker sets `birdyBirdProvider`, so the whole app previews each bird; the
/// button, like the arrow, goes back.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/birdy_tokens.dart';
import '../design/widgets/birdy_bird_picker.dart';
import '../design/widgets/birdy_list_row.dart';
import '../design/widgets/singing_theme_logo.dart';
import '../onboarding/onboarding_steps.dart';
import 'fork_prefs.dart';

class MyBirdScreen extends StatelessWidget {
  const MyBirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: BirdyBirdStep(
          onBack: () => Navigator.of(context).maybePop(),
          onDone: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// « Mon oiseau » row: the themed logo in a tonal disc, the bird's name, a
/// chevron; opens [MyBirdScreen].
class MyBirdRow extends ConsumerWidget {
  const MyBirdRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bird = ref.watch(birdyBirdProvider);
    return BirdyListRow(
      avatar: const SingingThemeLogo(
        size: BirdySizes.rowDisc,
        markWidth: BirdySizes.myBirdRowMark,
        halo: false,
        sings: false,
      ),
      title: l10n.forkSettingsMyBird,
      subtitle: bird.label(l10n),
      semanticLabel: '${l10n.forkSettingsMyBird}. ${bird.label(l10n)}',
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MyBirdScreen()),
          ),
    );
  }
}
