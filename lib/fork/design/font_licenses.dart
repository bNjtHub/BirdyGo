/// Registers the OFL licenses of the bundled fonts (J6a), so they appear
/// wherever the app lists its licenses.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Font families and their license files in assets/fonts/.
const Map<String, String> kForkFontLicenses = {
  'Fraunces': 'assets/fonts/OFL-Fraunces.txt',
  'Atkinson Hyperlegible Next': 'assets/fonts/OFL-AtkinsonHyperlegibleNext.txt',
};

void registerForkFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in kForkFontLicenses.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
