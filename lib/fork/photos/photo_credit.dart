/// Photo credit (J6b): a one-line credit under a photo, and the sheet with
/// author, licence and source that a tap on the photo opens.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import 'photo_manifest.dart';

/// Opens the credit sheet of [info].
Future<void> showPhotoCredit(BuildContext context, SpeciesPhotoInfo info) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => PhotoCreditSheet(info: info),
    );

/// "Jane Doe · CC BY-NC", or null when there is nothing to credit.
String? photoCreditText(SpeciesPhotoInfo info) {
  final parts =
      [info.author ?? info.source, info.license?.label].whereType<String>();
  return parts.isEmpty ? null : parts.join(' · ');
}

class PhotoCreditSheet extends StatelessWidget {
  const PhotoCreditSheet({super.key, required this.info});

  final SpeciesPhotoInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final license = info.license;
    final licenseUrl = license?.url;
    final pageUrl = info.pageUrl;

    Widget row(String value, String label, {String? url}) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: BirdySpace.gutter),
      title: Text(value),
      subtitle: Text(label),
      trailing: url == null ? null : const Icon(AppIcons.openInNew, size: 20),
      onTap: url == null ? null : () => openExternalUrl(context, url),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: BirdySpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BirdySpace.gutter,
              0,
              BirdySpace.gutter,
              BirdySpace.s,
            ),
            child: Semantics(
              header: true,
              child: Text(l10n.forkPhotoCreditTitle, style: BirdyText.heading),
            ),
          ),
          if (info.author case final author?)
            row(author, l10n.forkPhotoCreditAuthor),
          if (license != null)
            row(license.label, l10n.forkPhotoCreditLicense, url: licenseUrl),
          if (info.source case final source?)
            row(source, l10n.forkPhotoCreditSource, url: pageUrl),
          if (info.cropped)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BirdySpace.gutter,
                BirdySpace.s,
                BirdySpace.gutter,
                0,
              ),
              child: Text(
                l10n.forkPhotoCreditCropped,
                style: BirdyText.caption.copyWith(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Photo : Jane Doe · CC BY-NC" under a species photo; opens the sheet.
class PhotoCreditLine extends ConsumerWidget {
  const PhotoCreditLine({
    super.key,
    required this.scientificName,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 0),
  });

  final String scientificName;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(speciesPhotoProvider(scientificName)).value;
    final credit = info == null ? null : photoCreditText(info);
    if (info == null || credit == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => showPhotoCredit(context, info),
      child: Padding(
        padding: padding,
        child: Text(
          l10n.forkPhotoCreditLine(credit),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: BirdyText.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
