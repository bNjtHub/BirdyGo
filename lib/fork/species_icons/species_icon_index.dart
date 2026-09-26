/// Parsed J6d species icon index and deterministic fallback resolution.
library;

import 'dart:convert';

const speciesIconsAssetDirectory = 'assets/fork/species_icons';
const speciesIconsIndexAsset = '$speciesIconsAssetDirectory/index.json';

enum SpeciesIconResolution { exact, alias, genus, family, mystery }

class ResolvedSpeciesIcon {
  const ResolvedSpeciesIcon({required this.asset, required this.resolution});

  final String asset;
  final SpeciesIconResolution resolution;
}

class SpeciesIconIndex {
  SpeciesIconIndex._({
    required this.species,
    required this.aliases,
    required this.genera,
    required this.genusFamilies,
    required this.families,
    required this.templates,
    required this.fallback,
  });

  factory SpeciesIconIndex.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported species icon index');
    }
    final rawSpecies = _object(decoded, 'species');
    final species = <String, String>{};
    for (final entry in rawSpecies.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic> || value['file'] is! String) {
        throw FormatException('Invalid species icon entry: ${entry.key}');
      }
      species[_key(entry.key)] = _safeFile(value['file'] as String);
    }
    final templates = _strings(decoded, 'templates').map((key, value) {
      if (!_templateId.hasMatch(key)) {
        throw FormatException('Invalid species icon template: $key');
      }
      return MapEntry(key, _safeFile(value));
    });
    return SpeciesIconIndex._(
      species: species,
      aliases: _normalized(_strings(decoded, 'aliases'), normalizeValues: true),
      genera: _normalized(_strings(decoded, 'genera')),
      genusFamilies: _normalized(
        _strings(decoded, 'genusFamilies'),
        normalizeValues: true,
      ),
      families: _normalized(_strings(decoded, 'families'), normalizeKeys: true),
      templates: templates,
      fallback: _safeFile(decoded['fallback'] as String? ?? 'mystere.svg'),
    );
  }

  final Map<String, String> species;
  final Map<String, String> aliases;
  final Map<String, String> genera;
  final Map<String, String> genusFamilies;
  final Map<String, String> families;
  final Map<String, String> templates;
  final String fallback;

  static final RegExp _safeSvg = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*\.svg$');
  static final RegExp _templateId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  int get assetCount => species.length + templates.length + 1;

  ResolvedSpeciesIcon resolve(String scientificName) {
    final name = _key(scientificName);
    final exact = species[name];
    if (exact != null) return _asset(exact, SpeciesIconResolution.exact);
    final canonical = aliases[name];
    final alias = canonical == null ? null : species[canonical];
    if (alias != null) return _asset(alias, SpeciesIconResolution.alias);
    final genus = name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
    if (genus != null) {
      final genusFile = _template(genera[genus]);
      if (genusFile != null) {
        return _asset(genusFile, SpeciesIconResolution.genus);
      }
      final family = genusFamilies[genus];
      final familyFile = _template(family == null ? null : families[family]);
      if (familyFile != null) {
        return _asset(familyFile, SpeciesIconResolution.family);
      }
    }
    return _asset(fallback, SpeciesIconResolution.mystery);
  }

  String? _template(String? templateId) =>
      templateId == null ? null : templates[templateId];

  static ResolvedSpeciesIcon _asset(
    String file,
    SpeciesIconResolution resolution,
  ) => ResolvedSpeciesIcon(
    asset: '$speciesIconsAssetDirectory/$file',
    resolution: resolution,
  );

  static Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid species icon index field: $key');
    }
    return value;
  }

  static Map<String, String> _strings(Map<String, dynamic> json, String key) {
    final value = _object(json, key);
    if (value.values.any((item) => item is! String)) {
      throw FormatException('Invalid species icon index field: $key');
    }
    return value.map((name, item) => MapEntry(name, item as String));
  }

  static String _safeFile(String value) {
    if (!_safeSvg.hasMatch(value)) {
      throw FormatException('Invalid species icon file: $value');
    }
    return value;
  }

  static String _key(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Map<String, String> _normalized(
    Map<String, String> values, {
    bool normalizeKeys = true,
    bool normalizeValues = false,
  }) => values.map(
    (key, value) => MapEntry(
      normalizeKeys ? _key(key) : key,
      normalizeValues ? _key(value) : value,
    ),
  );
}
