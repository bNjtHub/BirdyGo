/// Notebook model (J6e, SPEC.md 9.10): which cards the collection shows, in
/// which order, and what each filter keeps. Pure, so it is tested alone.
library;

import '../../features/inference/geo_abundance.dart';
import '../reliability/reliability_config.dart';

/// Rarity mark of a card, from the geo-model at the user's place this week
/// (SPEC.md 7.6).
enum RarityMark {
  none,

  /// « Peu commun »: half disc.
  uncommon,

  /// « Rare »: Loriot diamond.
  rare,

  /// Not expected here this week at all: Loriot star.
  exceptional,
}

enum NotebookCardKind {
  /// Verified at least once (Sûr or confirmed): in color.
  discovered,

  /// Heard, never verified, with detections waiting in the quick review.
  toConfirm,

  /// Expected here this week, never heard: silhouette and hint.
  mystery,
}

enum NotebookFilter { all, discovered, toDiscover, rare }

/// One card of the notebook.
class NotebookCard {
  const NotebookCard({
    required this.kind,
    required this.scientificName,
    required this.commonName,
    this.contacts = 0,
    this.isNew = false,
    this.rarity = RarityMark.none,
    this.hint,
  });

  final NotebookCardKind kind;
  final String scientificName;

  /// Never shown on a mystery card.
  final String commonName;

  /// « N fois ».
  final int contacts;

  /// Discovered and its fiche never opened from the notebook.
  final bool isNew;
  final RarityMark rarity;

  /// Mystery clue (« Chante au lever du jour dans les haies. »).
  final String? hint;
}

/// A species heard, as the notebook needs it.
class HeardSpecies {
  const HeardSpecies({
    required this.scientificName,
    required this.commonName,
    required this.contacts,
    required this.verified,
    required this.inQueue,
  });

  final String scientificName;
  final String commonName;
  final int contacts;
  final bool verified;
  final int inQueue;
}

/// A species the geo-model expects here this week.
class ExpectedSpecies {
  const ExpectedSpecies({
    required this.scientificName,
    required this.commonName,
    required this.score,
    required this.tier,
  });

  final String scientificName;
  final String commonName;

  /// Raw geo-model probability this week (0–1).
  final double score;
  final ExploreTier tier;
}

/// Everything the notebook screen shows.
class Notebook {
  const Notebook({
    required this.cards,
    required this.discovered,
    required this.expected,
    required this.expectedFound,
  });

  /// Cards in the « Toutes » order.
  final List<NotebookCard> cards;

  /// Species discovered, everywhere.
  final int discovered;

  /// Species expected here this week; null without a place.
  final int? expected;

  /// Expected species already discovered.
  final int expectedFound;

  List<NotebookCard> filtered(NotebookFilter filter) => [
    for (final card in cards)
      if (keeps(filter, card)) card,
  ];
}

/// Whether [filter] keeps [card] (SPEC.md 9.10).
bool keeps(NotebookFilter filter, NotebookCard card) => switch (filter) {
  NotebookFilter.all => true,
  NotebookFilter.discovered => card.kind == NotebookCardKind.discovered,
  NotebookFilter.toDiscover => card.kind != NotebookCardKind.discovered,
  NotebookFilter.rare =>
    card.kind != NotebookCardKind.mystery && card.rarity != RarityMark.none,
};

/// A mystery card after every [mysteryEvery] other cards in « Toutes »,
/// like the mockup; the others follow at the end.
const int mysteryEvery = 3;

/// Builds the notebook.
///
/// [heard] comes from the index (birds only), [expected] from the geo-model
/// at the user's place (birds only; null without a place), [seen] lists the
/// species whose fiche was opened from the notebook, [hints] gives the
/// mystery clues.
Notebook buildNotebook({
  required List<HeardSpecies> heard,
  required List<ExpectedSpecies>? expected,
  required Set<String> seen,
  required String? Function(String scientificName) hint,
}) {
  final expectedByName = {
    for (final species in expected ?? const <ExpectedSpecies>[])
      species.scientificName: species,
  };
  RarityMark rarityOf(String name) {
    if (expected == null || expected.isEmpty) return RarityMark.none;
    final tier = expectedByName[name]?.tier;
    if (tier == null) return RarityMark.exceptional;
    if (ReliabilityConfig.rareTiers.contains(tier)) return RarityMark.rare;
    if (ReliabilityConfig.uncommonTiers.contains(tier)) {
      return RarityMark.uncommon;
    }
    return RarityMark.none;
  }

  final fresh = <NotebookCard>[];
  final toConfirm = <NotebookCard>[];
  final known = <NotebookCard>[];
  final heardNames = <String>{};
  for (final species in heard) {
    heardNames.add(species.scientificName);
    if (species.verified) {
      final card = NotebookCard(
        kind: NotebookCardKind.discovered,
        scientificName: species.scientificName,
        commonName: species.commonName,
        contacts: species.contacts,
        isNew: !seen.contains(species.scientificName),
        rarity: rarityOf(species.scientificName),
      );
      (card.isNew ? fresh : known).add(card);
    } else if (species.inQueue > 0) {
      toConfirm.add(
        NotebookCard(
          kind: NotebookCardKind.toConfirm,
          scientificName: species.scientificName,
          commonName: species.commonName,
          contacts: species.contacts,
          rarity: rarityOf(species.scientificName),
        ),
      );
    }
  }
  int byContacts(NotebookCard a, NotebookCard b) {
    final order = b.contacts.compareTo(a.contacts);
    return order != 0 ? order : a.commonName.compareTo(b.commonName);
  }

  fresh.sort(byContacts);
  toConfirm.sort(byContacts);
  known.sort(byContacts);

  // Most likely first: the first silhouettes are the easiest to find.
  final mysteries = [
    for (final species in [...?expected]
      ..sort((a, b) => b.score.compareTo(a.score)))
      if (!heardNames.contains(species.scientificName))
        NotebookCard(
          kind: NotebookCardKind.mystery,
          scientificName: species.scientificName,
          commonName: species.commonName,
          hint: hint(species.scientificName),
        ),
  ];

  final others = [...fresh, ...toConfirm, ...known];
  final cards = <NotebookCard>[];
  var mystery = 0;
  for (final (i, card) in others.indexed) {
    cards.add(card);
    if ((i + 1) % mysteryEvery == 0 && mystery < mysteries.length) {
      cards.add(mysteries[mystery++]);
    }
  }
  cards.addAll(mysteries.skip(mystery));

  final discovered = fresh.length + known.length;
  return Notebook(
    cards: cards,
    discovered: discovered,
    expected: expected?.length,
    expectedFound:
        [...fresh, ...known]
            .where((card) => expectedByName.containsKey(card.scientificName))
            .length,
  );
}
