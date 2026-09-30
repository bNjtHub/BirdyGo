/// What « Sûr », « Probable », « À vérifier » and « Rare ici » mean, opened
/// from the live options sheet (fork/PLAN.md J6c-bis-c).
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/birdy_sheet.dart';
import 'reliability_badge.dart';
import 'reliability_config.dart';

/// J6f: opened from the live options sheet (« À quel point l'app est
/// sûre »), on top of it.
///
/// J7: opened from the level badge of a live row, it starts with the
/// figures of that species ([species]).
Future<void> showLevelsSheet(BuildContext context, {LevelsSpecies? species}) {
  return showBirdySheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LevelsSheet(species: species),
  );
}

/// What the levels sheet says about one species of the outing (J7).
class LevelsSpecies {
  const LevelsSpecies({
    required this.name,
    required this.level,
    required this.bestScore,
    required this.bestAt,
    required this.contacts,
    this.unexpected = false,
  });

  final String name;
  final ReliabilityLevel level;

  /// Best score of the outing (0 to 1), and when that contact started.
  final double bestScore;
  final DateTime bestAt;

  /// Contacts of the outing.
  final int contacts;

  /// The species is unexpected here (« Rare ici · à confirmer » when the
  /// place alone makes it « À vérifier »).
  final bool unexpected;
}

class LevelsSheet extends StatelessWidget {
  const LevelsSheet({super.key, this.species});

  /// The species this sheet was opened from, if any.
  final LevelsSpecies? species;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    Widget row(Widget badge, String text) => Padding(
      padding: const EdgeInsets.only(bottom: BirdySpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(height: BirdySpace.xs),
          Text(text, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BirdySpace.gutter,
        0,
        BirdySpace.gutter,
        BirdySpace.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (species != null) ...[
            _SpeciesLevel(species: species!),
            const SizedBox(height: BirdySpace.xl),
          ],
          Text(
            l10n.forkLevelsInfoTitle,
            style: BirdyText.heading.copyWith(color: c.text1),
          ),
          const SizedBox(height: BirdySpace.l),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.sure),
            l10n.forkLevelsInfoSure,
          ),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.probable),
            l10n.forkLevelsInfoProbable,
          ),
          row(
            const ReliabilityBadge(level: ReliabilityLevel.toCheck),
            l10n.forkLevelsInfoToCheck,
          ),
          row(
            const NoveltyPill(kind: NoveltyKind.rareHereToConfirm),
            l10n.forkLevelsInfoRareHere,
          ),
          const SizedBox(height: BirdySpace.xs),
          Text(
            l10n.forkLevelsInfoFooter,
            style: BirdyText.caption.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }
}

/// The figures of one species: its level, best score, when, and contacts.
class _SpeciesLevel extends StatelessWidget {
  const _SpeciesLevel({required this.species});

  final LevelsSpecies species;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(species.bestAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: BirdySpace.xs),
      child: Text(text, style: BirdyText.bodyCompact.copyWith(color: c.text1)),
    );
    return Column(
      key: const ValueKey('levels-species'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forkLevelsSpeciesTitle(species.name),
          style: BirdyText.heading.copyWith(color: c.text1),
        ),
        const SizedBox(height: BirdySpace.s),
        ReliabilityBadge(
          level: species.level,
          unexpected: species.unexpected,
          score: species.bestScore,
        ),
        const SizedBox(height: BirdySpace.xs),
        line(l10n.forkLevelsSpeciesBestScore((species.bestScore * 100).round())),
        line(l10n.forkLevelsSpeciesBestAt(time)),
        line(l10n.forkLevelsSpeciesContacts(species.contacts)),
        const SizedBox(height: BirdySpace.xs),
        Text(
          l10n.forkLevelsSpeciesRule,
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
      ],
    );
  }
}
