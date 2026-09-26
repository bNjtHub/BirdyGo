import 'package:birdnet_live/fork/species_icons/species_icon_index.dart';
import 'package:flutter_test/flutter_test.dart';

const _index = '''
{
  "version": 1,
  "species": {"Parus major": {"file": "parus-major.svg", "template": "paridae"}},
  "aliases": {"Parus old": "Parus major"},
  "genera": {"Cyanistes": "paridae"},
  "genusFamilies": {"Poecile": "Paridae", "Unknown": "Missing"},
  "families": {"Paridae": "paridae"},
  "templates": {"paridae": "template-paridae.svg"},
  "fallback": "mystere.svg"
}
''';

void main() {
  test('resolves exact, alias, genus, family, then mystery', () {
    final index = SpeciesIconIndex.fromJson(_index);

    expect(
      index.resolve('Parus major').resolution,
      SpeciesIconResolution.exact,
    );
    expect(
      index.resolve('  PARUS   MAJOR ').resolution,
      SpeciesIconResolution.exact,
    );
    expect(index.resolve('Parus old').resolution, SpeciesIconResolution.alias);
    expect(
      index.resolve('Cyanistes caeruleus').resolution,
      SpeciesIconResolution.genus,
    );
    expect(
      index.resolve('Poecile palustris').resolution,
      SpeciesIconResolution.family,
    );
    final mystery = index.resolve('Unknown bird');
    expect(mystery.resolution, SpeciesIconResolution.mystery);
    expect(mystery.asset, 'assets/fork/species_icons/mystere.svg');
  });

  test(
    'rejects unsupported versions and paths outside the asset directory',
    () {
      expect(
        () => SpeciesIconIndex.fromJson(
          _index.replaceFirst('"version": 1', '"version": 2'),
        ),
        throwsFormatException,
      );
      expect(
        () => SpeciesIconIndex.fromJson(
          _index.replaceFirst('parus-major.svg', '../bird.svg'),
        ),
        throwsFormatException,
      );
      expect(
        () => SpeciesIconIndex.fromJson(
          _index.replaceFirst('template-paridae.svg', 'Template.svg'),
        ),
        throwsFormatException,
      );
      expect(
        () => SpeciesIconIndex.fromJson(
          _index.replaceFirst(
            '"paridae": "template-',
            '"Paridae!": "template-',
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
