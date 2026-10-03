/// Credit line under a species description: source, and for Wikipedia texts
/// the CC BY-SA 4.0 license, each with its link (fork/PLAN.md J7).
///
/// One place for the rule: the species page and the upstream info overlay
/// both use it.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/services/link_launcher.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'licenses_model.dart';

/// Wikipedia texts are CC BY-SA 4.0.
final String wikipediaTextLicenseUrl = LicenseFamily.bySa.deedUrl!;

/// True when the taxonomy `description_source` is Wikipedia.
bool isWikipediaSource(String? source) =>
    source != null && source.trim().toLowerCase() == 'wikipedia';

class DescriptionCredit extends StatelessWidget {
  const DescriptionCredit({
    super.key,
    required this.source,
    this.wikipediaUrl,
    this.style,
  });

  final String source;

  /// Page the text comes from, linked when the source is Wikipedia.
  final String? wikipediaUrl;

  /// Base text style; defaults to the caption style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final base = style ?? BirdyText.caption.copyWith(color: c.text2);
    if (!isWikipediaSource(source)) {
      return Text(l10n.speciesDescriptionSource(source), style: base);
    }
    final link = base.copyWith(decoration: TextDecoration.underline);
    Widget tap(Key key, String label, String url) => InkWell(
      key: key,
      onTap: () => openExternalUrl(context, url),
      child: Text(label, style: link),
    );
    return Wrap(
      children: [
        Text('${l10n.forkDescriptionSourceLabel} ', style: base),
        if (wikipediaUrl != null)
          tap(
            const ValueKey('description-credit-wikipedia'),
            'Wikipedia',
            wikipediaUrl!,
          )
        else
          Text('Wikipedia', style: base),
        Text(' · ', style: base),
        tap(
          const ValueKey('description-credit-license'),
          'CC BY-SA 4.0',
          wikipediaTextLicenseUrl,
        ),
      ],
    );
  }
}
