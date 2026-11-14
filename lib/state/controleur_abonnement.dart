import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/depot_abonnement.dart';
import '../domain/models/abonnement.dart';
import '../domain/models/offre.dart';

/// Petit stockage de la clé d'abonnement, abstrait pour les tests.
abstract class StockageCle {
  Future<String?> lire();

  Future<void> ecrire(String? valeur);
}

/// Implémentation réelle sur `SharedPreferences` (survit aux redémarrages).
class StockageClePreferences implements StockageCle {
  StockageClePreferences({SharedPreferences? preferences}) : _preferences = preferences;

  static const String cleStockage = '416_cle_abonnement';

  SharedPreferences? _preferences;

  Future<SharedPreferences?> _prefs() async {
    if (_preferences != null) return _preferences;
    try {
      _preferences = await SharedPreferences.getInstance();
    } catch (_) {
      return null; // Stockage indisponible : l'app continue sans persistance.
    }
    return _preferences;
  }

  @override
  Future<String?> lire() async {
    final prefs = await _prefs();
    final valeur = prefs?.getString(cleStockage);
    if (valeur == null || valeur.trim().isEmpty) return null;
    return valeur.trim();
  }

  @override
  Future<void> ecrire(String? valeur) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    if (valeur == null || valeur.trim().isEmpty) {
      await prefs.remove(cleStockage);
    } else {
      await prefs.setString(cleStockage, valeur.trim());
    }
  }
}

/// État partagé des abonnements : clé du compte, offres, abonnement en cours.
///
/// L'écran n'appelle jamais le réseau directement ; il lit ce contrôleur et
/// écoute ses notifications. Toutes les erreurs y arrivent déjà rédigées.
class ControleurAbonnement extends ChangeNotifier {
  ControleurAbonnement({
    required StockageCle stockage,
    required DepotAbonnement Function(String cle) creerDepot,
    String? cleInitiale,
  })  : _stockage = stockage,
        _creerDepot = creerDepot,
        _cle = cleInitiale;

  final StockageCle _stockage;
  final DepotAbonnement Function(String cle) _creerDepot;

  String? _cle;
  DepotAbonnement? _depot;
  List<Offre> _offres = const [];
  EtatAbonnement? _etat;
  String? _erreur;
  bool _chargement = false;
  bool _souscriptionEnCours = false;

  String? get cle => _cle;
  bool get aUneCle => _cle != null && _cle!.isNotEmpty;
  List<Offre> get offres => _offres;
  /// Motifs de refus du serveur qui prouvent que la clé ne servira plus jamais.
  /// Tout autre 401 (sans motif) est traité comme un incident passager.
  static const Set<String> motifsDefinitifs = {'remplacee', 'desactivee', 'expiree'};

  /// Vrai si ce refus prouve que la clé est définitivement perdue.
  static bool refusDefinitif(String? code) => code != null && motifsDefinitifs.contains(code);

  /// Phrase à montrer après une déconnexion forcée par le serveur.
  static String messageDeconnexion(String code) {
    switch (code) {
      case 'remplacee':
        return 'Votre compte est connecté sur un autre téléphone. Reconnectez-vous ici pour le reprendre.';
      case 'desactivee':
        return 'Votre compte a été désactivé. Contactez-nous sur WhatsApp.';
      default:
        return 'Votre session a expiré après une longue absence. Reconnectez-vous.';
    }
  }

  String? _motifDeconnexion;

  /// Message expliquant pourquoi la personne a été déconnectée (null sinon).
  String? get motifDeconnexion => _motifDeconnexion;

  void effacerMotifDeconnexion() {
    if (_motifDeconnexion == null) return;
    _motifDeconnexion = null;
    notifyListeners();
  }

  /// Le serveur a confirmé que la clé est révoquée : on l'oublie et on dit pourquoi.
  Future<void> oublierCleRevoquee(String code) async {
    _motifDeconnexion = messageDeconnexion(code);
    _cle = null;
    _depot = null;
    _etat = null;
    await _stockage.ecrire(null);
    notifyListeners();
  }

  EtatAbonnement? get etat => _etat;
  Abonnement? get abonnement => _etat?.pertinent;
  bool get abonne => _etat?.abonne ?? false;
  String? get erreur => _erreur;
  bool get chargement => _chargement;
  bool get souscriptionEnCours => _souscriptionEnCours;

  /// Vrai quand un paiement attend encore la validation de l'équipe 416.
  bool get enAttenteValidation => _etat?.enAttenteValidation ?? false;

  /// Relit la clé enregistrée puis charge offres et état de l'abonnement.
  Future<void> initialiser() async {
    _cle = await _stockage.lire();
    if (aUneCle) _depot = _creerDepot(_cle!);
    if (aUneCle) {
      await rafraichir();
    } else {
      // Sans clé, les offres restent consultables : c'est ce qui donne envie
      // de souscrire et ce qui permet de montrer les tarifs.
      await chargerOffres();
    }
  }

  /// Enregistre la clé du compte puis recharge l'état.
  Future<void> definirCle(String valeur) async {
    final propre = valeur.trim();
    if (propre.isNotEmpty) _motifDeconnexion = null;
    _cle = propre.isEmpty ? null : propre;
    await _stockage.ecrire(_cle);
    _depot = aUneCle ? _creerDepot(_cle!) : null;
    _etat = null;
    _erreur = null;
    if (aUneCle) {
      await rafraichir();
    } else {
      await chargerOffres();
    }
  }

  Future<void> chargerOffres() async {
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      _offres = await (_depot ?? _creerDepot('')).offres();
    } on ErreurAbonnement catch (erreur) {
      _erreur = erreur.message;
    } catch (_) {
      _erreur = 'Les offres sont momentanément indisponibles.';
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<void> rafraichir() async {
    if (!aUneCle) {
      await chargerOffres();
      return;
    }
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final depot = _depot ?? _creerDepot(_cle!);
      _depot = depot;
      // Les prix peuvent changer cote admin : on relit toujours les offres,
      // et si la relecture echoue on garde celles deja affichees.
      try {
        _offres = await depot.offres();
      } on ErreurAbonnement {
        if (_offres.isEmpty) rethrow;
      }
      _etat = await depot.monAbonnement();
    } on ErreurAbonnement catch (erreur) {
      _erreur = erreur.message;
      if (erreur.statut == 401 && refusDefinitif(erreur.code)) {
        // Le serveur a CONFIRMÉ que la clé est révoquée (remplacée, désactivée,
        // expirée) : on l'oublie. Un 401 sans motif (redémarrage du serveur,
        // proxy, ancien serveur) ne déconnecte jamais : la clé est conservée.
        await oublierCleRevoquee(erreur.code!);
      }
    } catch (_) {
      _erreur = 'Impossible de joindre le service d\'abonnement.';
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  /// Envoie une preuve de paiement Mobile Money.
  ///
  /// Renvoie l'abonnement créé, ou `null` si l'envoi a échoué (le message est
  /// alors dans [erreur]).
  Future<Abonnement?> souscrire({
    required Offre offre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  }) async {
    if (!aUneCle) {
      _erreur = 'Renseignez d\'abord votre clé d\'abonnement 416.';
      notifyListeners();
      return null;
    }
    _souscriptionEnCours = true;
    _erreur = null;
    notifyListeners();
    try {
      final depot = _depot ?? _creerDepot(_cle!);
      _depot = depot;
      final resultat = await depot.souscrire(
        codeOffre: offre.code,
        operateur: operateur,
        numeroTransaction: numeroTransaction,
        preuve: preuve,
      );
      _etat = await depot.monAbonnement();
      return resultat.abonnement;
    } on ErreurAbonnement catch (erreur) {
      _erreur = erreur.message;
      return null;
    } catch (_) {
      _erreur = 'Envoi impossible pour le moment. Réessayez dans un instant.';
      return null;
    } finally {
      _souscriptionEnCours = false;
      notifyListeners();
    }
  }

  /// Demande au serveur l'autorisation de lire un film.
  ///
  /// Lève [AccesRefuse] si le serveur refuse (402) : l'écran appelant ouvre
  /// alors les offres en affichant le message reçu.
  Future<LectureAutorisee> lectureFilm(String slug) async {
    final depot = _depot ?? (_cle == null ? null : _creerDepot(_cle!));
    if (depot == null) {
      throw const AccesRefuse(
        'Créez votre accès 416 pour regarder ce film : le compte se règle en ligne.',
      );
    }
    _depot = depot;
    return depot.lectureFilm(slug);
  }
}
