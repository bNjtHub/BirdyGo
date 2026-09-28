/// French definite article for a bird's common name (« le merle noir »,
/// « la mésange bleue », « l'étourneau sansonnet »), for the quiz reveal.
///
/// The taxonomy gives no grammatical gender, so the article comes from the
/// name's first word: a vowel or a mute h takes « l' », a known head noun or
/// adjective takes « le » or « la ». An unknown word gives null, and the
/// caller falls back to « C'est bien : Nom ».
library;

/// [name] with its article and a lower-case first letter, or null when the
/// gender of its first word is unknown.
String? frenchWithArticle(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed[0].toLowerCase() + trimmed.substring(1);
  final head = lower.split(RegExp(r"[\s'’]")).first;
  final key = _fold(head);
  if (_aspiratedH.contains(key)) {
    return _feminine.contains(key) ? 'la $lower' : 'le $lower';
  }
  if (RegExp('^[aeiouyh]').hasMatch(key)) return "l'$lower";
  if (_feminine.contains(key)) return 'la $lower';
  if (_masculine.contains(key)) return 'le $lower';
  // Compound heads (« pie-grièche », « martin-pêcheur »): first part.
  final part = key.split('-').first;
  if (part != key) {
    if (_feminine.contains(part)) return 'la $lower';
    if (_masculine.contains(part)) return 'le $lower';
  }
  return null;
}

/// Lower case without accents, for the word lists.
String _fold(String word) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final buffer = StringBuffer();
  for (final rune in word.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    buffer.write(i < 0 ? char : to[i]);
  }
  return buffer.toString();
}

/// Words starting with an aspirated h: no elision.
const Set<String> _aspiratedH = {
  'harfang',
  'harle',
  'heron',
  'hibou',
  'hulotte',
  'huppe',
  'hobereau',
};

const Set<String> _feminine = {
  'alouette',
  'bartavelle',
  'becasse',
  'bergeronnette',
  'bondree',
  'bouscarle',
  'buse',
  'caille',
  'chevechette',
  'cheveche',
  'chouette',
  'cigogne',
  'cisticole',
  'corneille',
  'fauvette',
  'foulque',
  'gallinule',
  'gelinotte',
  'gorgebleue',
  'grande',
  'grive',
  'grue',
  'hulotte',
  'huppe',
  'linotte',
  'locustelle',
  'macreuse',
  'marouette',
  'mesange',
  'mouette',
  'nette',
  'niverolle',
  'panure',
  'perdrix',
  'petite',
  'pie',
  'poule',
  'rousserolle',
  'sarcelle',
  'sittelle',
  'sterne',
  'tourterelle',
};

const Set<String> _masculine = {
  'balbuzard',
  'bec',
  'becasseau',
  'bouvreuil',
  'bruant',
  'busard',
  'butor',
  'canard',
  'chardonneret',
  'chevalier',
  'choucas',
  'cincle',
  'circaete',
  'cochevis',
  'corbeau',
  'cormoran',
  'coucou',
  'courlis',
  'crave',
  'cygne',
  'faisan',
  'faucon',
  'geai',
  'gobemouche',
  'goeland',
  'grand',
  'gravelot',
  'grebe',
  'grimpereau',
  'gros',
  'guepier',
  'gypaete',
  'harfang',
  'harle',
  'heron',
  'hibou',
  'hobereau',
  'jaseur',
  'loriot',
  'martin',
  'martinet',
  'merle',
  'milan',
  'moineau',
  'petit',
  'pic',
  'pigeon',
  'pingouin',
  'pinson',
  'pipit',
  'pluvier',
  'pouillot',
  'rale',
  'roitelet',
  'rollier',
  'rossignol',
  'rougegorge',
  'rouge',
  'rougequeue',
  'serin',
  'tadorne',
  'tarier',
  'tarin',
  'tichodrome',
  'torcol',
  'traquet',
  'troglodyte',
  'vanneau',
  'vautour',
  'verdier',
};
