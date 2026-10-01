/// Registers the OFL licenses of the bundled fonts (J6a), so they appear
/// wherever the app lists its licenses.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Font families and their license files in assets/fonts/.
const Map<String, String> kForkFontLicenses = {
  'Nunito': 'assets/fonts/OFL-Nunito.txt',
  'Fraunces': 'assets/fonts/OFL-Fraunces.txt',
  'Atkinson Hyperlegible Next': 'assets/fonts/OFL-AtkinsonHyperlegibleNext.txt',
};

void registerForkFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in kForkFontLicenses.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
    // Natural Earth land outline of the species page world map (J7).
    yield LicenseEntryWithLineBreaks(
      ['Natural Earth (land 1:110m)'],
      await rootBundle.loadString('assets/fork/world/LICENSE.txt'),
    );
  });
}
