import 'dart:io';

import 'package:birdnet_live/features/history/services/share_file_params.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('shareParamsForFile', () {
    test('uses the basename for title, override, and XFile name', () {
      final filePath = p.join(
        Directory.systemTemp.path,
        'BirdyGo_2026-07-01.wav',
      );
      final params = shareParamsForFile(
        filePath,
        text: 'body',
        subject: 'subject',
      );

      expect(params.files, hasLength(1));
      expect(params.files!.single.name, 'BirdyGo_2026-07-01.wav');
      expect(params.fileNameOverrides, ['BirdyGo_2026-07-01.wav']);
      expect(params.title, 'BirdyGo_2026-07-01.wav');
      expect(params.text, 'body');
      expect(params.subject, 'subject');
    });

    test('uses basename overrides for slash styles from other platforms', () {
      final androidParams = shareParamsForFile(
        '/data/user/0/app/cache/BirdyGo_clip.wav',
      );
      expect(androidParams.fileNameOverrides, ['BirdyGo_clip.wav']);
      expect(androidParams.title, 'BirdyGo_clip.wav');

      final windowsParams = shareParamsForFile(
        r'C:\Temp\BirdyGo_clip.flac',
      );
      expect(windowsParams.fileNameOverrides, ['BirdyGo_clip.flac']);
      expect(windowsParams.title, 'BirdyGo_clip.flac');
    });

    test('sets audio MIME types from file extensions', () {
      expect(mimeTypeForSharedPath('clip.wav'), 'audio/wav');
      expect(mimeTypeForSharedPath('clip.flac'), 'audio/flac');
      expect(mimeTypeForSharedPath('clip.mp3'), 'audio/mpeg');
      expect(mimeTypeForSharedPath('clip.ogg'), 'audio/ogg');
    });

    test('sets export document MIME types from file extensions', () {
      expect(mimeTypeForSharedPath('session.zip'), 'application/zip');
      expect(mimeTypeForSharedPath('session.json'), 'application/json');
      expect(mimeTypeForSharedPath('session.csv'), 'text/csv');
      expect(mimeTypeForSharedPath('track.gpx'), 'application/gpx+xml');
      expect(mimeTypeForSharedPath('report.html'), 'text/html');
      expect(mimeTypeForSharedPath('selection.txt'), 'text/plain');
    });
  });
}
