import 'dart:async';
import 'package:flutter/foundation.dart';

import '../domain/depot_comptes.dart';
import '../domain/depot_social.dart';
import '../domain/models/compte.dart';
import 'controleur_abonnement.dart';

/// État du compte client : inscription, connexion, déconnexion, suppression.
///
/// La clé d'accès reste portée par [ControleurAbonnement] (déjà stockée et
/// envoyée sur toutes les requêtes). Ce contrôleur la lui remet à la
/// connexion et la lui retire à la déconnexion : une seule source de vérité.
class ControleurCompte extends ChangeNotifier {
  ControleurCompte({
    required DepotComptes depot,
    required ControleurAbonnement abonnement,
    DepotSocial? social,
  })  : _depot = depot,
        _abonnement = abonnement,
        _social = social;

  final DepotComptes _depot;
  final ControleurAbonnement _abonnement;
  final DepotSocial? _social;

  Compte? _compte;
  String? _erreur;
  bool _occupe = false;
  FournisseursConnexion _fournisseurs = const FournisseursConnexion();
  bool _fournisseursCharges = false;

  Compte? get compte => _compte;
  bool get connecte => _compte != null;
  String? get erreur => _erreur;
  bool get occupe => _occupe;

  /// Fournisseurs de connexion annoncés par le serveur (Google, Telegram).
  FournisseursConnexion get fournisseurs => _fournisseurs;

  /// Charge une seule fois la liste des fournisseurs.
  Future<void> chargerFournisseurs() async {
    if (_fournisseursCharges || _social == null) return;
    _fournisseursCharges = true;
    try {
      _fournisseurs = await _social.fournisseurs();
    } catch (_) {
      _fournisseursCharges = false; // nouvel essai au prochain écran
    }
    notifyListeners();
  }

  /// Connexion par Google : l'application fournit le jeton d'identité obtenu
  /// auprès de Google, le serveur le vérifie et ouvre le compte.
  Future<bool> connecterGoogle(String jetonIdentite) {
    final social = _social;
    if (social == null) return Future.value(false);
    return _ouvrirSession(() => social.google(jetonIdentite));
  }

  /// Ouvre une demande Telegram : le lien à faire ouvrir et le jeton à suivre.
  Future<DemandeTelegram?> demarrerTelegram() async {
    final social = _social;
    if (social == null) return null;
    _erreur = null;
    notifyListeners();
    try {
      return await social.demarrerTelegram();
    } on ErreurCompte catch (e) {
      _erreur = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _erreur = 'Connexion Telegram indisponible pour le moment.';
      notifyListeners();
      return null;
    }
  }

  Completer<void> _reveil = Completer<void>();

  /// Appelé au retour au premier plan : vérifie tout de suite si Telegram a
  /// confirmé, sans attendre le prochain tour (l'application peut avoir été
  /// suspendue par Android pendant que Telegram était ouvert).
  void verifierTelegramMaintenant() {
    if (!_reveil.isCompleted) _reveil.complete();
  }

  /// Attend la confirmation Telegram, en interrogeant le serveur.
  Future<bool> attendreTelegram(
    String jeton, {
    Duration intervalle = const Duration(seconds: 2),
    Duration limite = const Duration(minutes: 10),
  }) async {
    final social = _social;
    if (social == null) return false;
    final fin = DateTime.now().add(limite);
    var premier = true;
    while (DateTime.now().isBefore(fin)) {
      // Premier tour sans attendre, puis toutes les [intervalle]. Un retour au
      // premier plan (Telegram vient d'être quitté) relance aussi la vérification.
      if (!premier) {
        await Future.any<void>([
          Future<void>.delayed(intervalle),
          _reveil.future,
        ]);
      }
      premier = false;
      if (_reveil.isCompleted) _reveil = Completer<void>();
      try {
        final session = await social.etatTelegram(jeton);
        if (session != null) {
          await _appliquer(session);
          return true;
        }
      } on ErreurCompte catch (e) {
        // Refus définitifs (jeton expiré, compte désactivé, limite de
        // téléphones, mise à jour requise) : on s'arrête et on explique, au lieu
        // de laisser l'écran attendre sans fin.
        const definitifs = {403, 404, 410, 426};
        if (definitifs.contains(e.statut)) {
          _erreur = e.message;
          notifyListeners();
          return false;
        }
      } catch (_) {
        // Réseau instable : on continue d'attendre.
      }
    }
    return false;
  }

  /// Enregistre une session obtenue par un autre chemin que le mot de passe.
  Future<void> _appliquer(SessionCompte session) async {
    _compte = session.compte;
    _erreur = null;
    await _abonnement.definirCle(session.cle);
    notifyListeners();
  }

  /// Au démarrage : retrouve le compte lié à la clé enregistrée.
  ///
  /// Réseau en panne, serveur qui se réveille ou 401 sans motif : on garde la
  /// clé et on réessaiera (retour au premier plan). La clé n'est effacée que si
  /// le serveur confirme qu'elle est révoquée (remplacée, désactivée, expirée).
  Future<void> initialiser() async {
    final cle = _abonnement.cle;
    if (cle == null || cle.isEmpty) return;
    try {
      _compte = await _depot.moi(cle);
    } on ErreurCompte catch (e) {
      if (e.statut == 401 && ControleurAbonnement.refusDefinitif(e.code)) {
        _compte = null;
        await _abonnement.oublierCleRevoquee(e.code!);
      }
    } catch (_) {
      // Hors ligne : rien à faire.
    }
    notifyListeners();
  }

  /// À appeler quand l'application revient au premier plan : retrouve le compte
  /// si le démarrage a échoué (réseau, serveur en veille) et détecte une
  /// révocation confirmée par le serveur. Sans effet si tout va bien.
  Future<void> reverifier() async {
    if (_occupe || _verification) return;
    final cle = _abonnement.cle;
    if (cle == null || cle.isEmpty) return;
    _verification = true;
    try {
      await initialiser();
    } finally {
      _verification = false;
    }
  }

  bool _verification = false;

  Future<bool> inscrire({
    required String identifiant,
    required String motDePasse,
    String nom = '',
  }) {
    return _ouvrirSession(
      () => _depot.inscrire(identifiant: identifiant, motDePasse: motDePasse, nom: nom),
    );
  }

  Future<bool> connecter({required String identifiant, required String motDePasse}) {
    return _ouvrirSession(
      () => _depot.connecter(identifiant: identifiant, motDePasse: motDePasse),
    );
  }

  Future<bool> _ouvrirSession(Future<SessionCompte> Function() action) async {
    if (_occupe) return false;
    _occupe = true;
    _erreur = null;
    notifyListeners();
    try {
      final session = await action();
      _compte = session.compte;
      await _abonnement.definirCle(session.cle);
      return true;
    } on ErreurCompte catch (e) {
      _erreur = e.message;
      return false;
    } catch (_) {
      _erreur = 'Une erreur inattendue est survenue. Réessayez.';
      return false;
    } finally {
      _occupe = false;
      notifyListeners();
    }
  }

  Future<void> deconnecter() async {
    _compte = null;
    _erreur = null;
    await _abonnement.definirCle('');
    notifyListeners();
  }

  /// Supprime définitivement le compte (mot de passe exigé).
  Future<bool> supprimer(String motDePasse) async {
    final cle = _abonnement.cle;
    if (cle == null || _occupe) return false;
    _occupe = true;
    _erreur = null;
    notifyListeners();
    try {
      await _depot.supprimer(cle: cle, motDePasse: motDePasse);
      _compte = null;
      await _abonnement.definirCle('');
      return true;
    } on ErreurCompte catch (e) {
      _erreur = e.message;
      return false;
    } catch (_) {
      _erreur = 'Suppression impossible pour le moment.';
      return false;
    } finally {
      _occupe = false;
      notifyListeners();
    }
  }

  void effacerErreur() {
    if (_erreur == null) return;
    _erreur = null;
    notifyListeners();
  }
}
