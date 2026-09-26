/// Licence of a species photo (J6b): short label and legal text link.
library;

import 'package:flutter/foundation.dart';

@immutable
class PhotoLicense {
  const PhotoLicense({required this.label, this.url});

  /// Reads an iNaturalist code (`cc-by-nc`) or a taxonomy.csv text
  /// (`CC BY-SA 3.0`, `© Macaulay Library`). Returns null for an empty text.
  ///
  /// iNaturalist codes carry no version: they link to the 4.0 deed, as
  /// iNaturalist does. Other texts are kept as they are, without a link.
  static PhotoLicense? parse(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final code = text.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');
    final match = _creativeCommons.firstMatch(code);
    if (match == null) return PhotoLicense(label: text);
    final kind = match.group(1)!;
    final version = match.group(2);
    if (kind == '0') {
      return const PhotoLicense(
        label: 'CC0',
        url: 'https://creativecommons.org/publicdomain/zero/1.0/',
      );
    }
    return PhotoLicense(
      label: 'CC ${kind.toUpperCase()}${version == null ? '' : ' $version'}',
      url: 'https://creativecommons.org/licenses/$kind/${version ?? '4.0'}/',
    );
  }

  static final RegExp _creativeCommons = RegExp(
    r'^cc-?(0|by(?:-nc)?(?:-sa|-nd)?)(?:-(\d(?:\.\d)?))?$',
  );

  /// "CC BY-NC", "CC BY-SA 3.0", "CC0", or the text as found.
  final String label;

  /// Legal text of a Creative Commons licence.
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is PhotoLicense && other.label == label && other.url == url;

  @override
  int get hashCode => Object.hash(label, url);

  @override
  String toString() => 'PhotoLicense($label)';
}
