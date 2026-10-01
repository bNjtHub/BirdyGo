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
  enemies('enemies'),
  byEar('by_ear'),
  confusions('confusions'),
  anecdote('anecdote');

  const SheetSection(this.key);

  final String key;
}

/// Nesting period of a species, in calendar months (1 to 12). [to] may be
/// before [from] when the period crosses the new year.
class NestingPeriod {
  const NestingPeriod(this.from, this.to);

  /// Parses the bundle's « M-N » text (e.g. « 4-7 »); null when missing or
  /// invalid, so a bad value never shows a wrong band.
  static NestingPeriod? tryParse(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(
      r'^\s*(\d{1,2})\s*[-–]\s*(\d{1,2})\s*$',
    ).firstMatch(raw);
    if (match == null) return null;
    final from = int.parse(match.group(1)!);
    final to = int.parse(match.group(2)!);
    if (from < 1 || from > 12 || to < 1 || to > 12) return null;
    return NestingPeriod(from, to);
  }

  final int from;
  final int to;

  /// Whether [month] (1 to 12) is in the period.
  bool includes(int month) =>
      from <= to ? month >= from && month <= to : month >= from || month <= to;

  @override
  bool operator ==(Object other) =>
      other is NestingPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'NestingPeriod($from-$to)';
}

/// One species sheet. Only non-empty sections are kept.
class SpeciesSheet {
  const SpeciesSheet({
    required this.name,
    required this.sections,
    this.hint,
    this.nesting,
  });

  factory SpeciesSheet.fromJson(Map<String, dynamic> json) => SpeciesSheet(
    name: json['name'] as String? ?? '',
    sections: {
      for (final section in SheetSection.values)
        if ((json[section.key] as String?)?.trim().isNotEmpty ?? false)
          section: (json[section.key] as String).trim(),
    },
    hint: json['hint'] as String?,
    nesting: NestingPeriod.tryParse(json['nesting']),
  );

  final String name;
  final Map<SheetSection, String> sections;

  /// Short clue for the game notebook (J6e), not shown on the sheet.
  final String? hint;

  /// Optional nesting period, drawn on the species page's seasons chart.
  final NestingPeriod? nesting;
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

SpeciesSheets _parseSheets(Uint8List bytes) => SpeciesSheets.fromGzip(bytes);

/// Loads the bundle once; an unreadable bundle means no sheets.
final speciesSheetsProvider = FutureProvider<SpeciesSheets>((ref) async {
  try {
    final data = await rootBundle.load(speciesSheetsAsset);
    // Inflating and parsing the whole bundle is heavy: off the UI isolate.
    return await compute(_parseSheets, data.buffer.asUint8List());
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
