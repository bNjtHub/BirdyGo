import 'package:birdnet_live/features/inference/geo_abundance.dart';
import 'package:birdnet_live/fork/notebook/notebook_model.dart';
import 'package:flutter_test/flutter_test.dart';

HeardSpecies _heard(
  String name, {
  int contacts = 1,
  bool verified = true,
  int inQueue = 0,
}) => HeardSpecies(
  scientificName: name,
  commonName: name,
  contacts: contacts,
  verified: verified,
  inQueue: inQueue,
);

ExpectedSpecies _expected(
  String name,
  double score, [
  ExploreTier tier = ExploreTier.common,
]) => ExpectedSpecies(
  scientificName: name,
  commonName: name,
  score: score,
  tier: tier,
);

void main() {
  final heard = [
    _heard('Robin', contacts: 142),
    _heard('Woodpecker', contacts: 2),
    _heard('Hoopoe', contacts: 1, verified: false, inQueue: 1),
    _heard('Owl', contacts: 7),
    _heard('Oriole', contacts: 4),
    // Heard, never verified, nothing left to review: not shown.
    _heard('Skipped', verified: false),
  ];
  final expected = [
    _expected('Robin', 0.9),
    _expected('Woodpecker', 0.3),
    _expected('Owl', 0.1, ExploreTier.scarce),
    _expected('Hoopoe', 0.04, ExploreTier.rare),
    _expected('Wren', 0.8),
    _expected('Tit', 0.5),
  ];

  Notebook build({List<ExpectedSpecies>? exp, Set<String>? seen}) =>
      buildNotebook(
        heard: heard,
        expected: exp,
        seen: seen ?? {'Robin', 'Owl', 'Oriole'},
        hint: (name) => name == 'Wren' ? 'Chante fort pour sa taille.' : null,
      );

  test('only verified species are discovered', () {
    final notebook = build(exp: expected);
    final discovered = notebook.filtered(NotebookFilter.discovered);
    expect(discovered.map((c) => c.scientificName), [
      'Woodpecker',
      'Robin',
      'Owl',
      'Oriole',
    ]);
    expect(notebook.discovered, 4);
    expect(
      notebook.cards.map((c) => c.scientificName),
      isNot(contains('Skipped')),
    );
  });

  test('new first, then to confirm, then by contacts, mysteries woven in', () {
    final notebook = build(exp: expected);
    expect(notebook.cards.map((c) => (c.kind, c.scientificName)), [
      (NotebookCardKind.discovered, 'Woodpecker'),
      (NotebookCardKind.toConfirm, 'Hoopoe'),
      (NotebookCardKind.discovered, 'Robin'),
      (NotebookCardKind.mystery, 'Wren'),
      (NotebookCardKind.discovered, 'Owl'),
      (NotebookCardKind.discovered, 'Oriole'),
      (NotebookCardKind.mystery, 'Tit'),
    ]);
    expect(notebook.cards.first.isNew, isTrue);
    expect(notebook.cards[2].isNew, isFalse);
  });

  test('mysteries carry the hint, most likely first', () {
    final mysteries = build(exp: expected).filtered(NotebookFilter.toDiscover);
    expect(mysteries.map((c) => c.scientificName), ['Hoopoe', 'Wren', 'Tit']);
    expect(mysteries[1].hint, 'Chante fort pour sa taille.');
    expect(mysteries[2].hint, isNull);
  });

  test('rarity marks come from the tier here this week', () {
    final notebook = build(exp: expected);
    RarityMark mark(String name) =>
        notebook.cards.firstWhere((c) => c.scientificName == name).rarity;
    expect(mark('Robin'), RarityMark.none);
    expect(mark('Owl'), RarityMark.uncommon);
    expect(mark('Hoopoe'), RarityMark.rare);
    expect(mark('Oriole'), RarityMark.exceptional);
    expect(
      notebook.filtered(NotebookFilter.rare).map((c) => c.scientificName),
      ['Hoopoe', 'Owl', 'Oriole'],
    );
  });

  test('progress counts expected species already discovered', () {
    final notebook = build(exp: expected);
    expect(notebook.expected, 6);
    expect(notebook.expectedFound, 3); // Robin, Woodpecker, Owl.
  });

  test('without a place: no mysteries, no rarity, no expected count', () {
    final notebook = build();
    expect(notebook.expected, isNull);
    expect(
      notebook.cards.where((c) => c.kind == NotebookCardKind.mystery),
      isEmpty,
    );
    expect(notebook.cards.every((c) => c.rarity == RarityMark.none), isTrue);
  });
}
