import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdygo_silhouette.dart';
import 'package:birdnet_live/fork/game/fine_ear_quiz_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the quiz mystery disc shows the shared « ? » on the bird', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        home: const Scaffold(
          body: Center(child: QuizMysteryDisc(size: 140, silhouette: 104)),
        ),
      ),
    );
    final icon = tester.widget<BirdyGoSilhouetteIcon>(
      find.byType(BirdyGoSilhouetteIcon),
    );
    expect(icon.role, SilhouetteRole.mystery);
    expect(find.byType(BirdyMysteryMark), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });
}
