/// Configuration réseau de l'application — **seul endroit** à modifier pour
/// basculer le catalogue d'un serveur à un autre.
///
/// Trois façons de fixer l'adresse, par ordre de priorité :
///   1. `flutter build web --dart-define=API_BASE=https://api.416.cd/api/`
///   2. `flutter run --dart-define=API_BASE=http://10.0.2.2:8416/api/`
///   3. la constante [defaut] ci-dessous (API de production).
///
/// L'URL est toujours normalisée avec un `/` final : les chemins relatifs
/// (`films/`, `artistes/<slug>/`…) sont ensuite simplement concaténés.
class ApiConfig {
  const ApiConfig._();

  /// Adresse par défaut : l'API de production (Render + Neon).
  /// Pour la mise au point locale : `--dart-define=API_BASE=http://10.0.2.2:8416/api/`.
  static const String defaut = 'https://api-416-records.onrender.com/api/';

  /// Valeur injectée au build (`--dart-define=API_BASE=…`). Vide si absente.
  static const String _surcharge = String.fromEnvironment('API_BASE');

  /// Adresse effective de l'API, avec un `/` final garanti.
  static String get base => normaliser(_surcharge.isEmpty ? defaut : _surcharge);

  /// Numéro WhatsApp qui reçoit les commandes. Surchargeable au build :
  /// `--dart-define=WHATSAPP_BOUTIQUE=+2439...`
  static const String whatsappBoutique = String.fromEnvironment(
    'WHATSAPP_BOUTIQUE',
    defaultValue: '+243977555768',
  );

  /// Identifiant client Google (projet Google Cloud « records-514210 »).
  /// C'est le client de type « Web » : il sert de serverClientId pour obtenir
  /// un jeton d'identité, que le serveur vérifie ensuite auprès de Google.
  /// Surchargeable au build : `--dart-define=GOOGLE_CLIENT_ID=...`.
  static const String identifiantGoogle = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '20914047619-nfbu3259if6ibq791e523tqons6t8h47.apps.googleusercontent.com',
  );

  /// Affiche le bouton « Continuer avec Google ». Désactivé : la connexion
  /// passe par Telegram et par e-mail. Réactivable au build avec
  /// `--dart-define=GOOGLE_VISIBLE=true` (le code Google est conservé).
  static const bool googleVisible = bool.fromEnvironment('GOOGLE_VISIBLE', defaultValue: false);

  /// Délai maximal d'une requête avant de considérer le serveur injoignable.
  static const Duration delai = Duration(seconds: 8);

  /// Vrai quand l'API a été fournie explicitement au build.
  static bool get surchargePresente => _surcharge.trim().isNotEmpty;

  /// Vrai quand l'API est servie par une fonction Base44 : la plateforme
  /// n'achemine pas les sous-chemins vers la fonction, la route doit donc
  /// voyager en paramètre (`?route=films/xxx`) et non dans le chemin.
  static bool get parRoute => base.contains('/functions/');

  /// Compose l'URL d'une route, quel que soit le type de serveur en face.
  static Uri uri(String base, String chemin, [Map<String, String>? parametres]) {
    final racine = normaliser(base);
    final parametresValides =
        (parametres == null || parametres.isEmpty) ? null : parametres;

    if (!racine.contains('/functions/')) {
      return Uri.parse('$racine$chemin')
          .replace(queryParameters: parametresValides);
    }

    final sansBarre =
        racine.endsWith('/') ? racine.substring(0, racine.length - 1) : racine;
    final route = chemin.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(sansBarre).replace(
      queryParameters: <String, String>{'route': route, ...?parametresValides},
    );
  }

  /// Ajoute le `/` final si nécessaire et retombe sur [defaut] si vide.
  static String normaliser(String url) {
    final propre = url.trim();
    if (propre.isEmpty) return defaut;
    return propre.endsWith('/') ? propre : '$propre/';
  }
}
