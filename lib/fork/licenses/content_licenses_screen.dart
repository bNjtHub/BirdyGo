/// « Licences des contenus » (fork/PLAN.md J7): author and license of every
/// bundled species photo, grouped by license, then the other contents
/// (fonts, model weights, species sheets, map tiles).
///
/// The list is built at runtime from the asset manifest and the taxonomy
/// the app already loads: the photo bundle is generated on the PC, so no
/// list is written in the code.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/explore/explore_providers.dart';
import '../../shared/services/link_launcher.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/widgets/birdy_block.dart';
import '../design/widgets/birdy_headers.dart';
import '../design/widgets/birdy_list_block.dart';
import '../design/widgets/birdy_list_row.dart';
import '../map/base_layers.dart';
import '../species_photo/species_photo_providers.dart';
import '../world_map/world_map_config.dart';
import 'description_credit.dart';
import 'licenses_model.dart';

/// Widest column on tablets.
const double _maxWidth = 600;

/// Rows shown per license before « Voir plus ».
const int kLicensesPageSize = 40;

const String _apacheUrl = 'https://www.apache.org/licenses/LICENSE-2.0';
const String _oflUrl = 'https://openfontlicense.org/';
const String _wikipediaUrl = 'https://www.wikipedia.org/';
const String _osmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// Bundled photos with their credit, in the app language.
final licensedPhotosProvider =
    FutureProvider.family<List<LicensedPhoto>, String>((ref, locale) async {
      final service = await ref.watch(taxonomyServiceProvider.future);
      final ids = await ref.watch(bundledImageIdsProvider.future);
      return licensedPhotos(service.allSpecies, ids, locale: locale);
    });

class ContentLicensesScreen extends ConsumerStatefulWidget {
  const ContentLicensesScreen({super.key});

  @override
  ConsumerState<ContentLicensesScreen> createState() =>
      _ContentLicensesScreenState();
}

class _ContentLicensesScreenState extends ConsumerState<ContentLicensesScreen> {
  final _controller = TextEditingController();
  String _query = '';
  final Map<LicenseFamily, int> _shown = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() {
    _query = value;
    _shown.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final photos = ref.watch(licensedPhotosProvider(locale));
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(BirdySpace.page),
              children: [
                BirdyOverlayHeader(title: l10n.forkLicensesTitle),
                const SizedBox(height: BirdySpace.block),
                _SearchField(controller: _controller, onChanged: _setQuery),
                const SizedBox(height: BirdySpace.block),
                ..._photoBlocks(l10n, c, photos),
                const SizedBox(height: BirdySpace.block),
                ..._gbifBlock(context, l10n),
                _otherBlock(context, l10n),
                const SizedBox(height: BirdySpace.block),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _photoBlocks(
    AppLocalizations l10n,
    BirdyColors c,
    AsyncValue<List<LicensedPhoto>> photos,
  ) {
    final intro = Padding(
      padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xs),
      child: Text(
        l10n.forkLicensesPhotosIntro,
        style: BirdyText.caption.copyWith(color: c.text2),
      ),
    );
    Widget note(String text) => BirdyBlock(
      child: Text(text, style: BirdyText.body.copyWith(color: c.text2)),
    );
    final heading = Padding(
      padding: const EdgeInsets.symmetric(horizontal: BirdySpace.xs),
      child: Text(
        l10n.forkLicensesPhotosTitle,
        style: BirdyText.heading.copyWith(color: c.text1),
      ),
    );
    return photos.when(
      loading:
          () => [
            heading,
            const SizedBox(height: BirdySpace.s),
            const Center(child: CircularProgressIndicator()),
          ],
      error: (_, _) => [heading, const SizedBox(height: BirdySpace.s)],
      data: (list) {
        final groups = groupByFamily(list, query: _query);
        return [
          heading,
          const SizedBox(height: BirdySpace.s),
          intro,
          const SizedBox(height: BirdySpace.m),
          if (list.isEmpty)
            note(l10n.forkLicensesNoPhotos)
          else if (groups.isEmpty)
            note(l10n.forkLicensesNoMatch)
          else
            for (final e in groups.entries) ...[
              _familyBlock(l10n, c, e.key, e.value),
              const SizedBox(height: BirdySpace.block),
            ],
        ];
      },
    );
  }

  Widget _familyBlock(
    AppLocalizations l10n,
    BirdyColors c,
    LicenseFamily family,
    List<LicensedPhoto> items,
  ) {
    final shown = (_shown[family] ?? kLicensesPageSize).clamp(0, items.length);
    final deed = family.deedUrl;
    return BirdyListBlock(
      key: ValueKey('licenses-${family.name}'),
      title: _familyName(l10n, family),
      trailing: Text(
        '${items.length}',
        style: BirdyText.captionTabular.copyWith(color: c.text2),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(BirdySpace.l),
          child: Text(
            _familyExplain(l10n, family),
            style: BirdyText.body.copyWith(color: c.text2),
          ),
        ),
        if (deed != null)
          BirdyListRow(
            key: ValueKey('licenses-deed-${family.name}'),
            icon: AppIcons.gavel,
            title: l10n.forkLicensesDeed,
            trailing: Icon(
              AppIcons.openInNew,
              size: BirdyGlyph.xl,
              color: c.text2,
            ),
            onTap: () => openExternalUrl(context, deed),
          ),
        for (final p in items.take(shown))
          BirdyListRow(
            key: ValueKey('licenses-photo-${p.birdnetId}'),
            title: p.commonName,
            titleStyle: BirdyText.species.copyWith(color: c.text1),
            subtitle:
                '${p.author ?? l10n.forkLicensesUnknownAuthor} · ${p.licenseLabel}',
            showChevron: false,
            trailing:
                p.pageUrl == null
                    ? null
                    : Icon(AppIcons.openInNew, size: BirdyGlyph.xl, color: c.text2),
            onTap: p.pageUrl == null ? null : () => openExternalUrl(context, p.pageUrl!),
          ),
        if (shown < items.length)
          BirdyListRow(
            key: ValueKey('licenses-more-${family.name}'),
            title: l10n.forkLicensesShowMore(items.length - shown),
            showChevron: false,
            onTap:
                () => setState(
                  () => _shown[family] = shown + kLicensesPageSize,
                ),
          ),
      ],
    );
  }

  /// Credit of the GBIF observations behind the species world map: what is
  /// filtered, that maps are made on demand, and the citation GBIF asks for.
  List<Widget> _gbifBlock(BuildContext context, AppLocalizations l10n) {
    final c = BirdyColors.of(context);
    Widget open() => Icon(AppIcons.openInNew, size: BirdyGlyph.xl, color: c.text2);
    return [
      BirdyListBlock(
        key: const ValueKey('licenses-gbif'),
        title: l10n.forkLicensesGbifTitle,
        children: [
          BirdyListRow(
            icon: AppIcons.gavel,
            title: l10n.forkLicensesGbifRow,
            subtitle: l10n.forkLicensesGbifRowSub('${WorldMapConfig.gbifFirstYear}'),
            trailing: open(),
            onTap: () => openExternalUrl(context, WorldMapConfig.gbifLicenseUrl),
          ),
          BirdyListRow(
            key: const ValueKey('licenses-gbif-citation'),
            icon: AppIcons.menuBook,
            title: l10n.forkLicensesGbifCitationTitle,
            subtitle: l10n.forkLicensesGbifCitation(
              DateFormat.yMMMMd(Localizations.localeOf(context).toString())
                  .format(WorldMapConfig.gbifDownloadDate),
              WorldMapConfig.gbifDownloadUrl,
            ),
            trailing: open(),
            onTap: () => openExternalUrl(context, WorldMapConfig.gbifDownloadUrl),
          ),
        ],
      ),
      const SizedBox(height: BirdySpace.block),
    ];
  }

  Widget _otherBlock(BuildContext context, AppLocalizations l10n) {
    final c = BirdyColors.of(context);
    final maps = [
      for (final layer in MapBaseLayer.values)
        ...baseLayerAttributions(layer),
    ];
    return BirdyListBlock(
      key: const ValueKey('licenses-other'),
      title: l10n.forkLicensesOtherTitle,
      children: [
        BirdyListRow(
          icon: AppIcons.menuBook,
          title: l10n.forkLicensesFonts,
          subtitle: l10n.forkLicensesFontsSub,
          onTap: () => openExternalUrl(context, _oflUrl),
        ),
        BirdyListRow(
          icon: AppIcons.gavel,
          title: l10n.forkLicensesModel,
          subtitle: l10n.forkLicensesModelSub,
          onTap: () => openExternalUrl(context, _apacheUrl),
        ),
        BirdyListRow(
          key: const ValueKey('licenses-wikipedia'),
          icon: AppIcons.menuBook,
          title: l10n.forkLicensesWikipedia,
          subtitle: l10n.forkLicensesWikipediaSub,
          trailing: Icon(AppIcons.openInNew, size: BirdyGlyph.xl, color: c.text2),
          onTap: () => openExternalUrl(context, wikipediaTextLicenseUrl),
        ),
        BirdyListRow(
          key: const ValueKey('licenses-wikipedia-site'),
          icon: AppIcons.public,
          title: l10n.forkLicensesWikipediaSite,
          trailing: Icon(AppIcons.openInNew, size: BirdyGlyph.xl, color: c.text2),
          onTap: () => openExternalUrl(context, _wikipediaUrl),
        ),
        BirdyListRow(
          key: const ValueKey('licenses-sheets'),
          icon: AppIcons.menuBook,
          title: l10n.forkLicensesSheets,
          subtitle: l10n.forkLicensesSheetsSub,
          trailing: Icon(AppIcons.openInNew, size: BirdyGlyph.xl, color: c.text2),
          onTap: () => openExternalUrl(context, wikipediaTextLicenseUrl),
        ),
        BirdyListRow(
          icon: AppIcons.mapSheet,
          title: l10n.forkLicensesMaps,
          subtitle: '${l10n.forkLicensesMapsSub}\n${maps.join(' · ')}',
          onTap: () => openExternalUrl(context, _osmCopyrightUrl),
        ),
        BirdyListRow(
          key: const ValueKey('licenses-code'),
          icon: AppIcons.public,
          title: l10n.forkLicensesCode,
          subtitle: l10n.forkLicensesCodeSub,
          onTap:
              () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
              ),
        ),
      ],
    );
  }
}

String _familyName(AppLocalizations l10n, LicenseFamily f) =>
    f.code ??
    switch (f) {
      LicenseFamily.publicDomain => l10n.forkLicensesFamilyPublicDomain,
      LicenseFamily.reserved => l10n.forkLicensesFamilyReserved,
      _ => l10n.forkLicensesFamilyOther,
    };

String _familyExplain(AppLocalizations l10n, LicenseFamily f) => switch (f) {
  LicenseFamily.by => l10n.forkLicensesExplainBy,
  LicenseFamily.bySa => l10n.forkLicensesExplainBySa,
  LicenseFamily.byNc => l10n.forkLicensesExplainByNc,
  LicenseFamily.byNd => l10n.forkLicensesExplainByNd,
  LicenseFamily.cc0 => l10n.forkLicensesExplainCc0,
  LicenseFamily.publicDomain => l10n.forkLicensesExplainPublicDomain,
  LicenseFamily.reserved => l10n.forkLicensesExplainReserved,
  LicenseFamily.other => l10n.forkLicensesExplainOther,
};

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return BirdyBlock(
      padding: const EdgeInsets.symmetric(horizontal: BirdySpace.l),
      child: Row(
        children: [
          Icon(AppIcons.search, size: BirdyGlyph.xxl, color: c.text2),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: TextField(
              key: const ValueKey('licenses-search'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: BirdyText.label.copyWith(color: c.text1),
              decoration: InputDecoration(
                hintText: l10n.forkLicensesSearchHint,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
