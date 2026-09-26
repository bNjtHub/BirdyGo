import 'dart:convert';

import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:birdnet_live/fork/species_icons/species_icon.dart';
import 'package:birdnet_live/fork/species_icons/species_icon_index.dart';
import 'package:birdnet_live/fork/species_icons/species_icon_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="20"/></svg>';
const _index =
    '''{"version":1,"species":{"Parus major":{"file":"parus-major.svg","template":"paridae"}},"aliases":{},"genera":{},"genusFamilies":{},"families":{},"templates":{"paridae":"template-paridae.svg"},"fallback":"mystere.svg"}''';

class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this.assets);

  final Map<String, String> assets;
  final Map<String, int> loads = {};

  @override
  Future<ByteData> load(String key) async {
    loads.update(key, (count) => count + 1, ifAbsent: () => 1);
    final value = assets[key];
    if (value == null) throw FlutterError('Missing $key');
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}

Widget _app(Widget child, AssetBundle bundle) => ProviderScope(
  overrides: [speciesIconAssetBundleProvider.overrideWithValue(bundle)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('markers share an index and decoded SVG across repeated builds', (
    tester,
  ) async {
    final bundle = _MemoryBundle({
      speciesIconsIndexAsset: _index,
      'assets/fork/species_icons/parus-major.svg': _svg,
      'assets/fork/species_icons/mystere.svg': _svg,
    });
    Widget tree(double size) => _app(
      Column(
        children: [
          SpeciesIcon(scientificName: 'Parus major', size: size),
          SpeciesIcon(scientificName: 'Parus major', size: size + 2),
          SpeciesIcon(scientificName: 'Unknown bird', size: size),
        ],
      ),
      bundle,
    );
    await tester.pumpWidget(tree(34));
    await tester.pumpAndSettle();
    await tester.pumpWidget(tree(40));
    await tester.pumpAndSettle();
    expect(bundle.loads[speciesIconsIndexAsset], 1);
    expect(bundle.loads['assets/fork/species_icons/parus-major.svg'], 1);
    expect(bundle.loads['assets/fork/species_icons/mystere.svg'], 1);
    expect(find.byType(SvgPicture), findsNWidgets(3));
  });

  testWidgets(
    'large avatars keep a photo even with an explicit icon fallback',
    (tester) async {
      const fallbackKey = ValueKey('explicit-icon');
      await tester.pumpWidget(
        MaterialApp(
          home: SpeciesAvatar(
            image: MemoryImage(Uint8List.fromList(const <int>[0])),
            icon: const SizedBox(key: fallbackKey),
            size: 80,
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(fallbackKey), findsNothing);
    },
  );

  testWidgets('renders an indexed SVG and applies the pending treatment', (
    tester,
  ) async {
    final bundle = _MemoryBundle({
      speciesIconsIndexAsset: _index,
      'assets/fork/species_icons/parus-major.svg': _svg,
    });
    await tester.pumpWidget(
      _app(
        const SpeciesIcon(scientificName: 'Parus major', size: 40, muted: true),
        bundle,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);
  });

  testWidgets('index failures show a quiet bird fallback', (tester) async {
    await tester.pumpWidget(
      _app(
        const SpeciesIcon(scientificName: 'Parus major', size: 40),
        _MemoryBundle(const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Icon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small avatars prefer SVG while large avatars keep photos', (
    tester,
  ) async {
    final bundle = _MemoryBundle({
      speciesIconsIndexAsset: _index,
      'assets/fork/species_icons/parus-major.svg': _svg,
    });
    final image = MemoryImage(Uint8List.fromList(const <int>[0]));
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            SpeciesAvatar(
              image: image,
              scientificName: 'Parus major',
              size: 40,
            ),
            SpeciesAvatar(
              image: image,
              scientificName: 'Parus major',
              size: 64,
            ),
          ],
        ),
        bundle,
      ),
    );

    expect(find.byType(SpeciesIcon), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a failed large photo falls back to its species icon', (
    tester,
  ) async {
    final bundle = _MemoryBundle({
      speciesIconsIndexAsset: _index,
      'assets/fork/species_icons/parus-major.svg': _svg,
    });
    await tester.pumpWidget(
      _app(
        SpeciesAvatar(
          image: MemoryImage(Uint8List.fromList(const <int>[0])),
          scientificName: 'Parus major',
          size: 64,
        ),
        bundle,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SpeciesIcon), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
