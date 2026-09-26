/// Blocks of the Bilan screen (J6c, fork/maquette/SPEC.md 9.8): top bar,
/// title, numbers, « Première fois » card, species to check, species strip.
library;

import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/app_icons.dart';
import '../../shared/utils/share_sheet.dart';
import '../design/birdy_tokens.dart';
import '../design/birdy_typography.dart';
import '../design/species_accents.dart';
import '../design/widgets/birdy_buttons.dart';
import '../design/widgets/birdy_pill.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/species_avatar.dart';
import '../reliability/reliability_badge.dart';
import 'bilan_model.dart';

/// Photo of a species, when there is one.
typedef SpeciesImageOf = ImageProvider? Function(String scientificName);

/// « ✕ Bilan de l'écoute … carte · partager ». [onMap] null hides the map
/// button (no position).
class BilanTopBar extends StatelessWidget {
  const BilanTopBar({
    super.key,
    required this.onClose,
    required this.onShare,
    this.onMap,
  });

  final VoidCallback onClose;
  final ShareFromOriginCallback onShare;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: BirdySizes.topBar),
      child: Row(
        children: [
          BirdyIconButton(
            icon: AppIcons.close,
            semanticLabel: l10n.forkBilanDone,
            onPressed: onClose,
          ),
          const SizedBox(width: BirdySpace.m),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.forkBilanTitle,
                style: BirdyText.heading.copyWith(color: c.text1),
              ),
            ),
          ),
          if (onMap != null) ...[
            BirdyIconButton(
              icon: AppIcons.mapSheet,
              semanticLabel: l10n.forkBilanOnMap,
              onPressed: onMap,
            ),
            const SizedBox(width: BirdySpace.s),
          ],
          Builder(
            builder:
                (button) => BirdyIconButton(
                  icon: AppIcons.share,
                  semanticLabel: l10n.forkBilanShare,
                  onPressed: () => onShare(shareOriginFrom(button)),
                ),
          ),
        ],
      ),
    );
  }
}

/// « Belle matinée ! » and the date line.
class BilanHero extends StatelessWidget {
  const BilanHero({super.key, required this.title, required this.dateLine});

  final String title;
  final String dateLine;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BirdyText.display.copyWith(color: c.text1)),
        const SizedBox(height: BirdySpace.xs),
        Text(dateLine, style: BirdyText.caption.copyWith(color: c.text2)),
      ],
    );
  }
}

/// One figure of the numbers row, without card (« 13 espèces »).
@immutable
class BilanFigure {
  const BilanFigure(this.value, this.label);

  final String value;
  final String label;
}

/// « 13 espèces · 52 contacts · 42 min ».
class BilanNumbers extends StatelessWidget {
  const BilanNumbers({super.key, required this.figures});

  final List<BilanFigure> figures;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) const SizedBox(width: BirdySpace.s),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    figures[i].value,
                    style: BirdyText.numberL.copyWith(color: c.text1),
                  ),
                  const SizedBox(height: BirdySpace.xs),
                  Text(
                    figures[i].label,
                    style: BirdyText.caption.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// « Première fois »: a new species with a Sûr or confirmed contact, on its
/// own color.
class BilanFirstTimeCard extends StatelessWidget {
  const BilanFirstTimeCard({
    super.key,
    required this.species,
    required this.caption,
    this.image,
    this.onTap,
  });

  final BilanSpecies species;

  /// « Entendu pour la première fois, à 7 h 26. »
  final String caption;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    final tint = SpeciesAccents.tintOf(species.scientificName);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.isDark ? tint.tintDark : tint.tintLight,
        borderRadius: BorderRadius.circular(BirdyRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.l,
                vertical: BirdySpace.m,
              ),
              child: Row(
                children: [
                  SpeciesAvatar(image: image, tint: tint, size: 80),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NoveltyPill(kind: NoveltyKind.firstTime),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          species.commonName,
                          style: BirdyText.title.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        Text(
                          caption,
                          style: BirdyText.body.copyWith(color: c.text1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A new species still to check (« Huppe fasciée · À vérifier · Inattendu
/// ici »), in grey until it is confirmed.
class BilanPendingRow extends StatelessWidget {
  const BilanPendingRow({
    super.key,
    required this.species,
    this.image,
    this.onTap,
  });

  final BilanSpecies species;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = BirdyColors.of(context);
    return Pressable(
      enabled: onTap != null,
      child: Material(
        color: c.surface1,
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BirdySizes.mainAction),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BirdySpace.m,
                vertical: BirdySpace.s,
              ),
              child: Row(
                children: [
                  SpeciesAvatar(
                    image: image,
                    tint: SpeciesAccents.tintOf(species.scientificName),
                    size: 40,
                    muted: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          species.commonName,
                          style: BirdyText.species.copyWith(color: c.text1),
                        ),
                        const SizedBox(height: BirdySpace.xs),
                        ReliabilityBadge(
                          level: species.level,
                          unexpected: species.unexpected,
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: c.text2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Les 13 espèces entendues » and one round item per species, scrolling
/// sideways. Species with nothing Sûr or confirmed carry a small dot.
class BilanSpeciesStrip extends StatelessWidget {
  const BilanSpeciesStrip({
    super.key,
    required this.species,
    this.imageOf,
    this.onTap,
  });

  final List<BilanSpecies> species;
  final SpeciesImageOf? imageOf;
  final ValueChanged<BilanSpecies>? onTap;

  /// Size of the circle (SPEC 9.8).
  static const double itemSize = 48;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.forkBilanSpeciesHeard(species.length),
          style: BirdyText.caption.copyWith(color: c.text2),
        ),
        const SizedBox(height: BirdySpace.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < species.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _StripItem(
                  species: species[i],
                  image: imageOf?.call(species[i].scientificName),
                  onTap: onTap == null ? null : () => onTap!(species[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.species, this.image, this.onTap});

  final BilanSpecies species;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = BirdyColors.of(context);
    const size = BilanSpeciesStrip.itemSize;
    final label = l10n.forkBilanSpeciesItem(species.commonName, species.count);
    return Semantics(
      button: onTap != null,
      label: species.pending ? '$label, ${l10n.forkBilanPendingNote}' : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: size),
          child: Column(
            children: [
              SizedBox.square(
                dimension: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SpeciesAvatar(
                      image: image,
                      tint: SpeciesAccents.tintOf(species.scientificName),
                      size: size,
                    ),
                    if (species.pending)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          key: const ValueKey('bilan-pending-dot'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.toCheck.foreground,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: BirdySpace.xs),
              Text(
                '×${species.count}',
                style: BirdyText.badge.copyWith(
                  color: c.text1,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
