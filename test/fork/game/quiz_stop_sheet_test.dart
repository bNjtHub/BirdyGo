import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/game/quiz_logo.dart';
import 'package:birdnet_live/fork/game/quiz_stop_sheet.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool? answer;

  Future<void> open(WidgetTester tester, {int right = 3}) async {
    answer = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: BirdyTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  answer = await showQuizStopSheet(context, right: right);
                },
                child: const Text('open'),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says what is kept, with the quiz logo', (tester) async {
    await open(tester);
    expect(find.text('Arrêter la partie ?'), findsOneWidget);
    expect(
      find.text(
        'Tes 3 bonnes réponses sont gardées pour le badge Oreille fine.',
      ),
      findsOneWidget,
    );
    expect(find.byType(QuizLogo), findsOneWidget);
    expect(
      tester.getSize(find.byType(QuizLogo)),
      const Size.square(BirdySizes.quizSheetDisc),
    );
  });

  testWidgets('« Arrêter » resolves to true', (tester) async {
    await open(tester);
    await tester.tap(find.text('Arrêter'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('« Continuer » and a dismissed sheet resolve to false', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
