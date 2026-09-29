import 'dart:ui' as ui;

import 'package:birdnet_live/fork/design/birdy_theme.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/design/birdy_tokens.dart';
import 'package:birdnet_live/fork/home/birdygo_logo.dart';
import 'package:birdnet_live/fork/listening_mode/listening_mode.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contrast_test.dart' show expectAA;

void main() {
  group('contrast per bird theme (>= 4.5:1)', () {
    for (final bird in BirdyBird.values) {
      test('${bird.name} light', () {
        final c = BirdyColors.forBird(bird, Brightness.light);
        expectAA(c.onAccent, c.accent, '$bird ink/accent');
        expectAA(c.accentText, c.surface1, '$bird accentText/white');
        expectAA(c.accentText, c.background, '$bird accentText/background');
        expectAA(c.accentText, c.tonal, '$bird accentText/tonal');
        expectAA(c.accentText, c.navIndicator, '$bird accentText/navIndicator');
        expectAA(
          c.accentText,
          Color.alphaBlend(c.tonal, c.background),
          '$bird accentText/tonal on background',
        );
      });

      test('${bird.name} dark', () {
        final c = BirdyColors.forBird(bird, Brightness.dark);
        final brand = BirdyBrandColors(bird, Brightness.dark);
        expectAA(c.onAccent, c.accent, '$bird ink/accent');
        expectAA(brand.accentTextDark, BirdyBrand.ink, '$bird accentTextDark');
        for (final bg in [c.background, c.surface1, c.surface2, c.surface3]) {
          expectAA(c.accentText, bg, '$bird accentText/dark surface');
        }
        expectAA(
          c.accentText,
          Color.alphaBlend(c.tonal, c.surface1),
          '$bird accentText/tonal on surface1',
        );
        expectAA(c.accentText, c.navIndicator, '$bird accentText/navIndicator');
      });
    }
  });

  group('Loriot is the look before J6i', () {
    for (final brightness in Brightness.values) {
      test('$brightness', () {
        final base =
            brightness == Brightness.dark
                ? BirdyColors.dark
                : BirdyColors.light;
        final brand = BirdyBrandColors(BirdyBird.loriot, brightness);
        expect(base.accent, brand.accent);
        expect(base.accent, BirdyBrand.kingfisher);
        expect(base.accentText, brand.accentText);
        expect(base.tonal, brand.tonal);
        expect(base.navIndicator, brand.navIndicator);
        expect(base.glow, brand.glow);
        expect(BirdyColors.forBird(BirdyBird.loriot, brightness), base);
      });
    }

    test('logo colors are the ones the painter always had', () {
      const brand = BirdyBrandColors(BirdyBird.loriot);
      expect(brand.accentHi, const Color(0xFF1CAEBA));
      expect(brand.accentDeep, const Color(0xFF0E7C86));
      expect(brand.highlight, BirdyBrand.oriole);
      expect(brand.highlightDeep, const Color(0xFFE3A22B));
      expect(brand.accentLight, BirdyBrand.wingSky);
      expect(BirdyGoLogoPainter.barsFor(brand), BirdyGoLogoPainter.bars);
    });
  });

  group('meaningful colors never change with the bird', () {
    for (final brightness in Brightness.values) {
      test('$brightness', () {
        final loriot = BirdyColors.forBird(BirdyBird.loriot, brightness);
        for (final bird in BirdyBird.values) {
          final c = BirdyColors.forBird(bird, brightness);
          expect(c.sure.foreground, loriot.sure.foreground);
          expect(c.sure.background, loriot.sure.background);
          expect(c.probable.foreground, loriot.probable.foreground);
          expect(c.probable.background, loriot.probable.background);
          expect(c.toCheck.foreground, loriot.toCheck.foreground);
          expect(c.toCheck.dashed, isTrue);
          expect(c.oriole, loriot.oriole);
          expect(c.onOriole, loriot.onOriole);
          expect(c.orioleText, loriot.orioleText);
          expect(c.orioleContainer, loriot.orioleContainer);
          expect(c.rarityMuted, loriot.rarityMuted);
          expect(c.onAccent, loriot.onAccent);
          expect(c.background, loriot.background);
          expect(c.surface1, loriot.surface1);
          expect(c.text1, loriot.text1);
          expect(c.text2, loriot.text2);
          expect(c.skeleton, loriot.skeleton);
        }
      });
    }

    test('listening modes other than Normal, and Normal follows the bird', () {
      for (final bird in BirdyBird.values) {
        for (final brightness in Brightness.values) {
          final c = BirdyColors.forBird(bird, brightness);
          final l = BirdyColors.forBird(BirdyBird.loriot, brightness);
          for (final mode in [
            ListeningMode.wind,
            ListeningMode.boost,
            ListeningMode.city,
          ]) {
            expect(listeningModeColor(c, mode), listeningModeColor(l, mode));
          }
          expect(listeningModeColor(c, ListeningMode.normal), c.accentText);
        }
      }
      expect(
        listeningModeColor(BirdyColors.light, ListeningMode.normal),
        ListeningModeColors.normalLight,
      );
      expect(
        listeningModeColor(BirdyColors.dark, ListeningMode.normal),
        ListeningModeColors.normalDark,
      );
    });

    test('the four themes differ in their brand roles', () {
      final accents = {
        for (final b in BirdyBird.values) BirdyBrandColors(b).accent,
      };
      expect(accents, hasLength(4));
    });
  });

  group('ThemeData', () {
    test('carries the bird and is cached per bird and brightness', () {
      for (final bird in BirdyBird.values) {
        final light = BirdyTheme.light(bird: bird);
        expect(BirdyTheme.light(bird: bird), same(light));
        expect(BirdyBrandColors.fromTheme(light).bird, bird);
        expect(
          BirdyColors.fromTheme(light).accent,
          BirdyBrandColors(bird).accent,
        );
        expect(light.colorScheme.primary, BirdyBrandColors(bird).accentText);
        expect(
          BirdyBrandColors.fromTheme(BirdyTheme.dark(bird: bird)).isDark,
          isTrue,
        );
      }
      expect(
        BirdyTheme.light(),
        same(BirdyTheme.light(bird: BirdyBird.loriot)),
      );
    });

    test('a theme without the extension falls back to Loriot', () {
      final brand = BirdyBrandColors.fromTheme(ThemeData.dark());
      expect(brand.bird, BirdyBird.loriot);
      expect(brand.isDark, isTrue);
    });
  });

  group('logo painters take the brand colors', () {
    Future<ui.Image> paint(BirdyBird bird) async {
      final recorder = ui.PictureRecorder();
      BirdyGoLogoPainter(
        progress: const AlwaysStoppedAnimation<double>(1),
        brand: BirdyBrandColors(bird),
      ).paint(Canvas(recorder), const Size.square(64));
      return recorder.endRecording().toImage(64, 64);
    }

    testWidgets('another bird paints other pixels', (tester) async {
      await tester.runAsync(() async {
        final loriot = await (await paint(BirdyBird.loriot)).toByteData();
        final flamant = await (await paint(BirdyBird.flamant)).toByteData();
        expect(
          loriot!.buffer.asUint8List(),
          isNot(flamant!.buffer.asUint8List()),
        );
      });
    });
  });

  group('persistence', () {
    Future<ProviderContainer> container(Map<String, Object> stored) async {
      SharedPreferences.setMockInitialValues(stored);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('defaults to Loriot', () async {
      final c = await container({});
      expect(c.read(birdyBirdProvider), BirdyBird.loriot);
      expect(birdyBirdFromPrefs(null), BirdyBird.loriot);
    });

    test('an unknown stored value falls back to Loriot', () async {
      final c = await container({kBirdyBirdPref: 'dodo'});
      expect(c.read(birdyBirdProvider), BirdyBird.loriot);
    });

    test('set updates the state and survives a restart', () async {
      final c = await container({});
      await c.read(birdyBirdProvider.notifier).set(BirdyBird.flamant);
      expect(c.read(birdyBirdProvider), BirdyBird.flamant);
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getString(kBirdyBirdPref), 'flamant');

      // A new process reads the same value, also before runApp.
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(birdyBirdProvider), BirdyBird.flamant);
      expect(birdyBirdFromPrefs(prefs), BirdyBird.flamant);
    });
  });
}
