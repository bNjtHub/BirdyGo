/// Breeding atlas codes proposed on an LPO card (fork/PLAN.md J5b).
///
/// Faune-France uses the EBCC atlas codes. A sound contact can only
/// support the two "possible breeder" codes, so BirdyGo proposes those,
/// and only during the species' breeding period in France. Outside it, or
/// for a species missing from [kBreedingPeriods], no code is proposed
/// (no code is always a valid answer on Faune-France).
library;

/// Atlas codes a sound contact can support.
enum AtlasCode {
  /// Present in its habitat during its breeding period.
  presentInHabitat(2),

  /// Singing male, nuptial calls or drumming heard during the breeding
  /// period.
  singingMale(3);

  const AtlasCode(this.number);

  final int number;
}

/// Code proposed first for a sound contact: a song heard during the
/// breeding period.
const AtlasCode kProposedAtlasCode = AtlasCode.singingMale;

/// A yearly window, bounds included, as (month, day) pairs.
class BreedingPeriod {
  const BreedingPeriod(
    this.startMonth,
    this.startDay,
    this.endMonth,
    this.endDay,
  );

  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  /// True when the calendar day of [date] is inside the window.
  bool contains(DateTime date) {
    final day = date.month * 100 + date.day;
    final start = startMonth * 100 + startDay;
    final end = endMonth * 100 + endDay;
    return start <= end
        ? day >= start && day <= end
        : day >= start || day <= end;
  }
}

/// Approximate breeding periods in France of the species with a bundled
/// sheet (J4b), from general ornithological knowledge: early for owls,
/// woodpeckers and corvids, late for trans-Saharan migrants. To check with
/// the local Faune-France coordinator; the observer always chooses.
const Map<String, BreedingPeriod> kBreedingPeriods = {
  'Accipiter nisus': BreedingPeriod(4, 1, 7, 31),
  'Acrocephalus schoenobaenus': BreedingPeriod(5, 1, 7, 31),
  'Acrocephalus scirpaceus': BreedingPeriod(5, 15, 8, 15),
  'Aegithalos caudatus': BreedingPeriod(3, 1, 6, 30),
  'Alauda arvensis': BreedingPeriod(4, 1, 7, 31),
  'Alcedo atthis': BreedingPeriod(3, 15, 8, 31),
  'Anas platyrhynchos': BreedingPeriod(3, 1, 7, 31),
  'Anthus pratensis': BreedingPeriod(4, 15, 7, 31),
  'Anthus trivialis': BreedingPeriod(4, 15, 7, 31),
  'Apus apus': BreedingPeriod(5, 1, 8, 15),
  'Ardea cinerea': BreedingPeriod(2, 1, 7, 31),
  'Asio otus': BreedingPeriod(2, 15, 7, 15),
  'Athene noctua': BreedingPeriod(3, 1, 7, 31),
  'Buteo buteo': BreedingPeriod(3, 1, 7, 31),
  'Carduelis carduelis': BreedingPeriod(4, 15, 8, 31),
  'Certhia brachydactyla': BreedingPeriod(3, 15, 7, 15),
  'Cettia cetti': BreedingPeriod(4, 1, 7, 31),
  'Chloris chloris': BreedingPeriod(4, 1, 8, 15),
  'Chroicocephalus ridibundus': BreedingPeriod(4, 15, 7, 31),
  'Ciconia ciconia': BreedingPeriod(3, 1, 7, 31),
  'Cisticola juncidis': BreedingPeriod(4, 1, 8, 31),
  'Coccothraustes coccothraustes': BreedingPeriod(4, 15, 7, 15),
  'Coloeus monedula': BreedingPeriod(3, 15, 6, 30),
  'Columba livia': BreedingPeriod(3, 1, 9, 30),
  'Columba palumbus': BreedingPeriod(3, 15, 9, 30),
  'Corvus corone': BreedingPeriod(3, 1, 6, 30),
  'Corvus frugilegus': BreedingPeriod(2, 15, 6, 15),
  'Cuculus canorus': BreedingPeriod(4, 15, 7, 15),
  'Curruca communis': BreedingPeriod(5, 1, 7, 31),
  'Cyanistes caeruleus': BreedingPeriod(3, 15, 6, 30),
  'Cygnus olor': BreedingPeriod(3, 15, 7, 31),
  'Delichon urbicum': BreedingPeriod(5, 1, 9, 15),
  'Dendrocopos major': BreedingPeriod(3, 1, 6, 30),
  'Dryobates minor': BreedingPeriod(3, 15, 6, 30),
  'Dryocopus martius': BreedingPeriod(3, 1, 6, 30),
  'Egretta garzetta': BreedingPeriod(4, 1, 7, 31),
  'Emberiza calandra': BreedingPeriod(4, 15, 7, 31),
  'Emberiza cirlus': BreedingPeriod(4, 15, 8, 15),
  'Emberiza citrinella': BreedingPeriod(4, 15, 8, 15),
  'Emberiza schoeniclus': BreedingPeriod(4, 15, 7, 31),
  'Erithacus rubecula': BreedingPeriod(3, 15, 7, 15),
  'Falco tinnunculus': BreedingPeriod(3, 15, 7, 31),
  'Fringilla coelebs': BreedingPeriod(4, 1, 7, 15),
  'Fulica atra': BreedingPeriod(3, 15, 8, 15),
  'Galerida cristata': BreedingPeriod(4, 1, 7, 31),
  'Gallinula chloropus': BreedingPeriod(4, 1, 8, 31),
  'Garrulus glandarius': BreedingPeriod(4, 1, 7, 15),
  'Hippolais polyglotta': BreedingPeriod(5, 15, 7, 31),
  'Hirundo rustica': BreedingPeriod(4, 15, 8, 31),
  'Lanius collurio': BreedingPeriod(5, 15, 8, 15),
  'Larus argentatus': BreedingPeriod(4, 15, 7, 31),
  'Larus michahellis': BreedingPeriod(3, 15, 7, 15),
  'Linaria cannabina': BreedingPeriod(4, 15, 8, 15),
  'Lophophanes cristatus': BreedingPeriod(3, 15, 6, 30),
  'Luscinia megarhynchos': BreedingPeriod(4, 15, 7, 15),
  'Merops apiaster': BreedingPeriod(5, 15, 8, 15),
  'Milvus migrans': BreedingPeriod(4, 1, 7, 31),
  'Milvus milvus': BreedingPeriod(3, 1, 7, 31),
  'Motacilla alba': BreedingPeriod(4, 1, 7, 31),
  'Motacilla cinerea': BreedingPeriod(3, 15, 7, 31),
  'Motacilla flava': BreedingPeriod(4, 15, 7, 31),
  'Muscicapa striata': BreedingPeriod(5, 15, 8, 15),
  'Oriolus oriolus': BreedingPeriod(5, 15, 7, 31),
  'Otus scops': BreedingPeriod(4, 15, 8, 15),
  'Parus major': BreedingPeriod(3, 15, 7, 15),
  'Passer domesticus': BreedingPeriod(4, 1, 8, 15),
  'Passer montanus': BreedingPeriod(4, 1, 8, 15),
  'Periparus ater': BreedingPeriod(3, 15, 7, 15),
  'Phalacrocorax carbo': BreedingPeriod(2, 1, 7, 31),
  'Phasianus colchicus': BreedingPeriod(4, 1, 7, 31),
  'Phoenicurus ochruros': BreedingPeriod(4, 1, 7, 31),
  'Phoenicurus phoenicurus': BreedingPeriod(4, 15, 7, 15),
  'Phylloscopus collybita': BreedingPeriod(3, 15, 7, 15),
  'Phylloscopus trochilus': BreedingPeriod(4, 15, 7, 15),
  'Pica pica': BreedingPeriod(3, 1, 6, 30),
  'Picus viridis': BreedingPeriod(3, 1, 7, 15),
  'Poecile palustris': BreedingPeriod(3, 15, 6, 30),
  'Prunella modularis': BreedingPeriod(4, 1, 7, 31),
  'Pyrrhula pyrrhula': BreedingPeriod(4, 15, 8, 15),
  'Regulus ignicapilla': BreedingPeriod(4, 15, 7, 31),
  'Regulus regulus': BreedingPeriod(4, 1, 7, 31),
  'Saxicola rubicola': BreedingPeriod(3, 15, 7, 31),
  'Serinus serinus': BreedingPeriod(4, 1, 8, 15),
  'Sitta europaea': BreedingPeriod(3, 15, 6, 30),
  'Spinus spinus': BreedingPeriod(4, 1, 7, 31),
  'Streptopelia decaocto': BreedingPeriod(3, 1, 9, 30),
  'Streptopelia turtur': BreedingPeriod(5, 1, 8, 15),
  'Strix aluco': BreedingPeriod(1, 15, 6, 30),
  'Sturnus vulgaris': BreedingPeriod(4, 1, 6, 30),
  'Sylvia atricapilla': BreedingPeriod(4, 1, 7, 31),
  'Sylvia borin': BreedingPeriod(5, 15, 7, 31),
  'Tachybaptus ruficollis': BreedingPeriod(4, 1, 8, 31),
  'Troglodytes troglodytes': BreedingPeriod(4, 1, 7, 31),
  'Turdus merula': BreedingPeriod(3, 1, 7, 31),
  'Turdus philomelos': BreedingPeriod(3, 15, 7, 31),
  'Turdus pilaris': BreedingPeriod(4, 15, 7, 15),
  'Turdus viscivorus': BreedingPeriod(3, 1, 6, 30),
  'Tyto alba': BreedingPeriod(3, 1, 9, 30),
  'Upupa epops': BreedingPeriod(4, 15, 7, 31),
  'Vanellus vanellus': BreedingPeriod(3, 15, 6, 30),
};

/// True when [date] falls in the breeding period of [scientificName].
bool inBreedingPeriod(String scientificName, DateTime date) =>
    kBreedingPeriods[scientificName]?.contains(date) ?? false;

/// Atlas codes to offer for a contact of [scientificName] on [date]: none
/// outside the breeding period, else the proposed code first.
List<AtlasCode> atlasCodesFor(String scientificName, DateTime date) =>
    inBreedingPeriod(scientificName, date)
        ? const [kProposedAtlasCode, AtlasCode.presentInHabitat]
        : const [];
