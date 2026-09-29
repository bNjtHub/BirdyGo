import 'package:birdnet_live/fork/app_icon/app_icon.dart';
import 'package:birdnet_live/fork/design/birdy_theme_choice.dart';
import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidAppIcon.channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidAppIcon.channel, null);
  });

  test('AndroidAppIcon sends setIcon with the bird name', () async {
    await AndroidAppIcon().set(BirdyBird.martin);
    expect(calls.single.method, 'setIcon');
    expect(calls.single.arguments, 'martin');
  });

  test('a missing native side is ignored', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidAppIcon.channel, null);
    await AndroidAppIcon().set(BirdyBird.flamant);
  });

  test('changing the bird theme calls the channel', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appIconProvider.overrideWithValue(AndroidAppIcon()),
      ],
    );
    addTearDown(c.dispose);

    c.listen(appIconSyncProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    // Once at start with the stored bird.
    expect(calls.map((c) => c.arguments), ['loriot']);

    await c.read(birdyBirdProvider.notifier).set(BirdyBird.etourneau);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.arguments), ['loriot', 'etourneau']);
    expect(calls.every((c) => c.method == 'setIcon'), isTrue);
  });
}
