import 'package:birdnet_live/fork/settings/fork_prefs.dart';
import 'package:birdnet_live/shared/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('first name: default null, trimmed, cut, empty clears', () async {
    final c = await _container({});
    expect(c.read(firstNameProvider), isNull);
    await c.read(firstNameProvider.notifier).set('  Benjamin ');
    expect(c.read(firstNameProvider), 'Benjamin');
    await c.read(firstNameProvider.notifier).set('x' * 40);
    expect(c.read(firstNameProvider)!.length, kFirstNameMaxLength);
    await c.read(firstNameProvider.notifier).set('   ');
    expect(c.read(firstNameProvider), isNull);
    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.containsKey(kFirstNamePref), isFalse);
  });

  test('first name is read back from the preferences', () async {
    final c = await _container({kFirstNamePref: ' Lou '});
    expect(c.read(firstNameProvider), 'Lou');
  });

  test('always-dark listening screen: off by default, persisted', () async {
    final c = await _container({});
    expect(c.read(liveAlwaysDarkProvider), isFalse);
    await c.read(liveAlwaysDarkProvider.notifier).set(true);
    expect(c.read(liveAlwaysDarkProvider), isTrue);
    expect(
      c.read(sharedPreferencesProvider).getBool(kLiveAlwaysDarkPref),
      isTrue,
    );
    final other = await _container({kLiveAlwaysDarkPref: true});
    expect(other.read(liveAlwaysDarkProvider), isTrue);
  });

  test('always-dark migrates the old explicit dark choice only', () async {
    final dark = await _container({kLiveThemePref: 'dark'});
    expect(dark.read(liveAlwaysDarkProvider), isTrue);
    final light = await _container({kLiveThemePref: 'light'});
    expect(light.read(liveAlwaysDarkProvider), isFalse);
    final both = await _container({
      kLiveThemePref: 'dark',
      kLiveAlwaysDarkPref: false,
    });
    expect(both.read(liveAlwaysDarkProvider), isFalse);
  });
}
