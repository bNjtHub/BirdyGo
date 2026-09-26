// Guards the fork's identity against upstream merges that would bring back
// the BirdNET Live name, identifiers or release workflows.
import 'dart:convert';
import 'dart:io';

import 'package:birdnet_live/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

const _appName = 'BirdyGo';
const _appId = 'fr.justcodeit.birdygo';
const _upstreamRepo = 'https://github.com/birdnet-team/birdnet-live-app';

String _read(String path) => File(path).readAsStringSync();

/// Top-level `on:` block of a GitHub Actions workflow.
String _triggers(String workflow) =>
    RegExp(r'^on:\n((?:[ #].*\n|\n)*)', multiLine: true)
        .firstMatch(workflow)!
        .group(1)!;

void main() {
  group('Android', () {
    test('applicationId is the fork one', () {
      final gradle = _read('android/app/build.gradle');
      expect(gradle, contains('applicationId = "$_appId"'));
      expect(gradle, isNot(contains('de.tu_chemnitz')));
    });

    test('launcher label is BirdyGo', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('android:label="$_appName"'));
    });
  });

  group('iOS', () {
    test('every bundle id is under the fork id', () {
      final pbxproj = _read('ios/Runner.xcodeproj/project.pbxproj');
      final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = "?([^";]+)"?;')
          .allMatches(pbxproj)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(id, startsWith(_appId));
      }
    });

    test('names and permission texts say BirdyGo', () {
      final plist = _read('ios/Runner/Info.plist');
      for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
        expect(
          plist,
          matches(RegExp('<key>$key</key>\\s*<string>$_appName</string>')),
          reason: key,
        );
      }
      expect(
        RegExp(r'<string>BirdNET Live [^<]*</string>').hasMatch(plist),
        isFalse,
      );
    });

    test('App Group is the fork one', () {
      expect(_read('ios/Runner/Runner.entitlements'),
          contains('group.$_appId'));
      expect(_read('ios/Runner/AppDelegate.swift'), contains('group.$_appId'));
    });
  });

  group('Flutter', () {
    test('appTitle is BirdyGo in every locale', () {
      final arbs = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();
      expect(arbs, isNotEmpty);
      for (final arb in arbs) {
        final json = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
        expect(json['appTitle'], _appName, reason: arb.path);
      }
    });

    test('app constants identify the fork', () {
      expect(AppConstants.appName, _appName);
      expect(AppConstants.packageName, _appId);
      expect(AppConstants.networkUserAgent, startsWith(_appName));
    });

    test('"Powered by BirdNET" links the upstream project', () {
      expect(AppConstants.githubUrl, _upstreamRepo);
    });

    test('no link to the private BirdyGo repository ships in the app', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f
              .readAsStringSync()
              .toLowerCase()
              .contains('github.com/bnjthub'))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
    });
  });

  group('Licensing', () {
    test('upstream licenses are kept', () {
      for (final path in ['LICENSE', 'MODEL_LICENSE', 'ACCEPTABLE_USE.md']) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('NOTICE states the app is a modified BirdNET Live', () {
      final notice = _read('NOTICE');
      expect(notice, contains('modified version of BirdNET Live'));
      expect(notice, contains(_upstreamRepo));
    });
  });

  group('Workflows', () {
    test('release and docs only run by hand', () {
      for (final path in [
        '.github/workflows/release.yml',
        '.github/workflows/docs.yml',
      ]) {
        final triggers = _triggers(_read(path));
        expect(triggers, contains('workflow_dispatch'), reason: path);
        for (final auto in ['push', 'pull_request', 'release', 'schedule']) {
          expect(triggers, isNot(contains('$auto:')), reason: path);
        }
      }
    });

    test('ci still runs on pull requests', () {
      expect(_triggers(_read('.github/workflows/ci.yml')),
          contains('pull_request:'));
    });
  });
}
