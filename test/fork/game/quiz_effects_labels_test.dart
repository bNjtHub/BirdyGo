import 'package:birdnet_live/fork/game/quiz_intro.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (locale, on, off) in [
    ('fr', 'Avec effets', 'Sans effets'),
    ('en', 'Effects on', 'Effects off'),
  ]) {
    testWidgets('quiz switch labels ($locale)', (tester) async {
      var value = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder:
              (context, setState) => MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: QuizSoundSwitch(
                    on: value,
                    onChanged: (v) => setState(() => value = v),
                  ),
                ),
              ),
        ),
      );
      expect(find.text(on), findsOneWidget);
      await tester.tap(find.byType(QuizSoundSwitch));
      await tester.pumpAndSettle();
      expect(find.text(off), findsOneWidget);
    });
  }
}
