import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdygo_silhouette.dart';
import 'package:birdnet_live/fork/design/widgets/species_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: BirdyTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('no photo, no icon: the BirdyGo silhouette on the halo', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Center(child: SpeciesAvatar(size: 48))));
    final icon = tester.widget<BirdyGoSilhouetteIcon>(
      find.byType(BirdyGoSilhouetteIcon),
    );
    expect(icon.size, closeTo(48 * 0.6, 0.001));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a given icon wins over the silhouette', (tester) async {
    await tester.pumpWidget(
      _app(const Center(child: SpeciesAvatar(icon: SizedBox(key: Key('own'))))),
    );
    expect(find.byKey(const Key('own')), findsOneWidget);
    expect(find.byType(BirdyGoSilhouetteIcon), findsNothing);
  });
}
