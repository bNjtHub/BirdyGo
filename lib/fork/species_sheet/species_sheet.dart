/// French species sheets written by AI and bundled with the app
/// (fork/PLAN.md J4b). Built by tools/fork_species_sheets.py.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/settings_providers.dart';

/// Bundled sheets, gzip-compressed JSON.
const speciesSheetsAsset = 'assets/fork/species_sheets_fr.json.gz';

/// Sections of a sheet, in display order, with their JSON keys.
enum SheetSection {
  summary('summary'),
  size('size'),
  behaviour('behaviour'),
  whyHere('why_here'),
  migration('migration'),
  byEar('by_ear'),
  confusions('confusions'),
  anecdote('anecdote');

  const SheetSection(this.key);

  final String key;
}

/// One species sheet. Only non-empty sections are kept.
class SpeciesSheet {
  const SpeciesSheet({required this.name, required this.sections, this.hint});

  factory SpeciesSheet.fromJson(Map<String, dynamic> json) => SpeciesSheet(
    name: json['name'] as String? ?? '',
    sections: {
      for (final section in SheetSection.values)
        if ((json[section.key] as String?)?.trim().isNotEmpty ?? false)
          section: (json[section.key] as String).trim(),
    },
    hint: json['hint'] as String?,
  );

  final String name;
  final Map<SheetSection, String> sections;

  /// Short clue for the game notebook (J6e), not shown on the sheet.
  final String? hint;
}

/// Every bundled sheet, by scientific name.
class SpeciesSheets {
  const SpeciesSheets(this._sheets);

  /// Parses the gzip-compressed bundle.
  factory SpeciesSheets.fromGzip(List<int> bytes) {
    final json =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    final species = json['species'] as Map<String, dynamic>? ?? const {};
    return SpeciesSheets({
      for (final entry in species.entries)
        entry.key: SpeciesSheet.fromJson(entry.value as Map<String, dynamic>),
    });
  }

  static const empty = SpeciesSheets({});

  final Map<String, SpeciesSheet> _sheets;

  SpeciesSheet? operator [](String scientificName) => _sheets[scientificName];

  int get length => _sheets.length;
}

/// The sheets are in French: shown only when species names are.
bool sheetsApplyTo(String speciesLocale) =>
    speciesLocale.toLowerCase().startsWith('fr');

/// Loads the bundle once; an unreadable bundle means no sheets.
final speciesSheetsProvider = FutureProvider<SpeciesSheets>((ref) async {
  try {
    final data = await rootBundle.load(speciesSheetsAsset);
    return SpeciesSheets.fromGzip(data.buffer.asUint8List());
  } catch (e) {
    debugPrint('[SpeciesSheets] not loaded: $e');
    return SpeciesSheets.empty;
  }
});

/// The sheet to show for [scientificName], or null (no sheet, sheets not
/// loaded yet, or species names not in French).
SpeciesSheet? watchSpeciesSheet(WidgetRef ref, String scientificName) {
  if (!sheetsApplyTo(ref.watch(effectiveSpeciesLocaleProvider))) return null;
  return ref.watch(speciesSheetsProvider).value?[scientificName];
}
