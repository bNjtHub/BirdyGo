/// Blurs the position of sensitive species in exports, in the spirit of
/// ACCEPTABLE_USE.md: « Consider the potential ecological impact of
/// publishing sensitive species locations » (fork/PLAN.md J5).
///
/// Positions stay precise on the phone (map, sessions); only exported
/// files are blurred. A blurred position snaps to the center of a grid
/// cell of [kSensitiveBlurDegrees], so repeated exports cannot be averaged
/// back to the real place.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/live/live_session.dart';
import 'map_config.dart';

/// SharedPreferences key of the export option (on by default).
const String kBlurSensitiveExportPref = 'fork_export_blur_sensitive';

/// Species whose breeding or roosting sites are commonly kept confidential
/// by French naturalist databases (Faune-France, INPN): mostly raptors,
/// owls, grouses and rare breeders disturbed by visitors.
///
/// Reviewed in J5b against the LPO practice: Faune-France hides the data
/// of the species of the national sensitive-data list (SINP) itself, and
/// asks observers to hide any data whose publication could disturb a bird.
/// This list follows the SINP birds (Booted Eagle, Eleonora's Falcon,
/// Short-eared Owl and the grey shrikes added in J5b); the LPO card
/// (lib/fork/lpo) proposes to hide the data of every species listed here.
/// Regional lists differ: check with the local coordinator.
const Set<String> kSensitiveSpecies = {
  'Aegolius funereus',
  'Aegypius monachus',
  'Acrocephalus paludicola',
  'Aquila chrysaetos',
  'Aquila fasciata',
  'Asio flammeus',
  'Botaurus stellaris',
  'Bubo bubo',
  'Ciconia nigra',
  'Circaetus gallicus',
  'Circus pygargus',
  'Crex crex',
  'Dendrocopos leucotos',
  'Emberiza hortulana',
  'Falco eleonorae',
  'Falco naumanni',
  'Falco peregrinus',
  'Glaucidium passerinum',
  'Gypaetus barbatus',
  'Gyps fulvus',
  'Hieraaetus pennatus',
  'Lagopus muta',
  'Lanius excubitor',
  'Lanius meridionalis',
  'Lanius minor',
  'Lyrurus tetrix',
  'Milvus milvus',
  'Neophron percnopterus',
  'Otus scops',
  'Pandion haliaetus',
  'Pterocles alchata',
  'Tetrao urogallus',
  'Tetrastes bonasia',
  'Tetrax tetrax',
};

/// True when [scientificName] is on the sensitive list.
bool isSensitiveSpecies(String scientificName) =>
    kSensitiveSpecies.contains(scientificName);

/// [value] (degrees) snapped to the center of its [kSensitiveBlurDegrees]
/// cell.
double blurDegrees(double value) {
  final cell = (value / kSensitiveBlurDegrees).floorToDouble();
  // Round away the float noise of the multiplication (6 decimals, as in
  // the exports).
  final center = (cell + 0.5) * kSensitiveBlurDegrees;
  return double.parse(center.toStringAsFixed(6));
}

/// Copy of [session] where every position that could reveal a sensitive
/// species is blurred: the positions of its detections and, since they
/// would give it away too, the session position, the GPS track and the
/// recorder deployment position. Sessions without a sensitive species are
/// returned as is.
LiveSession blurSensitivePositions(LiveSession session) {
  if (!session.detections.any((d) => isSensitiveSpecies(d.scientificName))) {
    return session;
  }
  final json = session.toJson();
  void blur(Map<String, dynamic> map, String latKey, String lonKey) {
    final lat = map[latKey];
    final lon = map[lonKey];
    if (lat is num) map[latKey] = blurDegrees(lat.toDouble());
    if (lon is num) map[lonKey] = blurDegrees(lon.toDouble());
  }

  blur(json, 'latitude', 'longitude');
  for (final d in (json['detections'] as List).cast<Map<String, dynamic>>()) {
    if (isSensitiveSpecies(d['scientificName'] as String)) {
      blur(d, 'detLat', 'detLon');
    }
  }
  final track = json['gpsTrack'] as List?;
  if (track != null) {
    for (final p in track.cast<Map<String, dynamic>>()) {
      blur(p, 'lat', 'lon');
    }
  }
  final aru = json['aru'];
  if (aru is Map<String, dynamic>) blur(aru, 'latitude', 'longitude');
  return LiveSession.fromJson(json);
}

/// Export hook: applies [blurSensitivePositions] when the option is on
/// (the default, also when the preferences cannot be read).
Future<LiveSession> applyExportPrivacy(LiveSession session) async {
  var enabled = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(kBlurSensitiveExportPref) ?? true;
  } catch (error) {
    debugPrint('Export privacy: preferences unavailable ($error)');
  }
  return enabled ? blurSensitivePositions(session) : session;
}
