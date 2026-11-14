import 'package:url_launcher/url_launcher.dart';

import '../domain/models/artiste.dart';
import '../domain/models/morceau.dart';

/// Plateformes sur lesquelles un morceau ou un artiste peut être écouté.
enum Plateforme { spotify, youtube, appleMusic, deezer, audiomack }

extension PlateformeInfo on Plateforme {
  String get libelle => switch (this) {
        Plateforme.spotify => 'Spotify',
        Plateforme.youtube => 'YouTube',
        Plateforme.appleMusic => 'Apple Music',
        Plateforme.deezer => 'Deezer',
        Plateforme.audiomack => 'Audiomack',
      };
}

/// Un lien d'écoute déjà validé : on ne garde que les adresses http(s).
class LienEcoute {
  const LienEcoute(this.plateforme, this.url);

  final Plateforme plateforme;
  final String url;

  /// Adresse à ouvrir. Pour un morceau Spotify on passe par le schéma
  /// `spotify:track:<id>` : l'application Spotify s'ouvre et lit réellement le
  /// titre (un simple lien web ouvert dans le navigateur n'est pas compté
  /// comme une écoute dans l'app).
  Uri get appNative {
    if (plateforme == Plateforme.spotify) {
      final deep = spotifyDeepLink(url);
      if (deep != null) return deep;
    }
    return Uri.parse(url);
  }

  Uri get web => Uri.parse(url);
}

String? _propre(String? valeur) {
  final v = valeur?.trim() ?? '';
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
    return null;
  }
  return v;
}

/// `https://open.spotify.com/track/<id>?si=…` -> `spotify:track:<id>`.
/// Renvoie null pour tout ce qui n'est pas un lien Spotify exploitable.
Uri? spotifyDeepLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.host.endsWith('spotify.com')) return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  // Les liens régionaux commencent par un segment « intl-fr ».
  if (segments.isNotEmpty && segments.first.startsWith('intl-')) segments.removeAt(0);
  if (segments.length < 2) return null;
  const types = {'track', 'album', 'artist', 'playlist'};
  if (!types.contains(segments[0])) return null;
  final id = segments[1];
  if (!RegExp(r'^[A-Za-z0-9]{10,40}$').hasMatch(id)) return null;
  return Uri.parse('spotify:${segments[0]}:$id');
}

List<LienEcoute> liensDuMorceau(Morceau m) => _liste({
      Plateforme.spotify: m.spotifyUrl,
      Plateforme.youtube: m.youtubeUrl,
      Plateforme.appleMusic: m.appleMusicUrl,
      Plateforme.deezer: m.deezerUrl,
      Plateforme.audiomack: m.audiomackUrl,
    });

List<LienEcoute> liensDeLArtiste(Artiste a) => _liste({
      Plateforme.spotify: a.spotifyUrl,
      Plateforme.youtube: a.youtubeUrl,
      Plateforme.appleMusic: a.appleMusicUrl,
      Plateforme.deezer: a.deezerUrl,
      Plateforme.audiomack: a.audiomackUrl,
    });

List<LienEcoute> _liste(Map<Plateforme, String?> brut) {
  final sortie = <LienEcoute>[];
  brut.forEach((plateforme, valeur) {
    final url = _propre(valeur);
    if (url != null) sortie.add(LienEcoute(plateforme, url));
  });
  return List.unmodifiable(sortie);
}

/// Ouvre le lien dans l'application de la plateforme, sinon dans le navigateur.
/// Renvoie false si rien n'a pu s'ouvrir.
Future<bool> ouvrirEcoute(LienEcoute lien) async {
  try {
    final natif = lien.appNative;
    if (natif != lien.web && await launchUrl(natif, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return await launchUrl(lien.web, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
