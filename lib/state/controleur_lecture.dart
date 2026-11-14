import 'dart:async';

import 'package:flutter/foundation.dart';

/// État d'une lecture, indépendant du plugin vidéo pour rester testable.
enum EtatLecture { preparation, prete, enCours, enPause, terminee, erreur }

/// Lecteur minimal que le plugin réel implémente (voir `LecteurVideoPlugin`).
/// Les tests fournissent une version simulée.
abstract class MoteurLecture {
  Future<void> ouvrir(Uri source);

  Future<void> lire();

  Future<void> pause();

  Future<void> aller(Duration position);

  /// Volume entre 0 et 1.
  Future<void> volume(double valeur);

  Future<void> fermer();

  Duration get position;

  Duration get duree;

  bool get enLecture;

  bool get enErreur;

  String? get messageErreur;

  /// Appelé à chaque changement d'état interne du moteur.
  void ecouter(VoidCallback rappel);
}

/// Pilote une lecture : préparation, lecture/pause, reprise, erreurs.
///
/// Règles tenues :
///  * la source n'est jamais exposée à l'interface (seul le moteur la voit) ;
///  * une URL absente, vide ou non http(s) est refusée avant d'appeler le moteur ;
///  * toute panne du moteur devient un message lisible, jamais une exception.
class ControleurLecture extends ChangeNotifier {
  ControleurLecture({required MoteurLecture moteur}) : _moteur = moteur {
    _moteur.ecouter(_surChangement);
  }

  final MoteurLecture _moteur;

  EtatLecture _etat = EtatLecture.preparation;
  double _volume = 1;
  String? _erreur;
  bool _ferme = false;

  /// Cible d'un saut en cours. Tant que le moteur n'a pas confirmé l'arrivée,
  /// la position affichée est cette cible : sinon on lirait l'ancienne position
  /// et les paroles reviendraient en arrière avant de se recaler.
  Duration? _cible;

  /// Numéro du dernier saut demandé : un saut plus ancien ne doit jamais
  /// écraser un saut plus récent (glissé sur la barre, touches rapides).
  int _numeroSaut = 0;

  /// Garde la fin d'un saut même si le moteur ne rend pas la main (web).
  Timer? _filet;

  EtatLecture get etat => _etat;
  String? get erreur => _erreur;
  Duration get position => _cible ?? _moteur.position;

  /// Vrai pendant qu'un saut n'est pas encore confirmé par le moteur.
  bool get enSaut => _cible != null;
  Duration get duree => _moteur.duree;
  bool get enLecture => _etat == EtatLecture.enCours;
  double get volume => _volume;

  /// Fraction lue entre 0 et 1 (0 si la durée est inconnue).
  double get progression {
    final total = duree.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Valide la source puis prépare le moteur.
  Future<void> preparer(String? source) async {
    final uri = _sourceValide(source);
    if (uri == null) {
      _echec('Ce contenu n\'est pas encore disponible en lecture.');
      return;
    }
    _etat = EtatLecture.preparation;
    _erreur = null;
    _notifier();
    try {
      await _moteur.ouvrir(uri);
      if (_ferme) return;
      if (_moteur.enErreur) {
        _echec(_moteur.messageErreur ?? 'La lecture a échoué.');
        return;
      }
      _etat = EtatLecture.prete;
      _notifier();
    } catch (_) {
      _echec('Impossible de lire ce contenu. Vérifiez votre connexion et réessayez.');
    }
  }

  Future<void> basculer() async {
    if (_ferme || _etat == EtatLecture.erreur || _etat == EtatLecture.preparation) return;
    try {
      if (_moteur.enLecture) {
        await _moteur.pause();
        _etat = EtatLecture.enPause;
      } else {
        if (_etat == EtatLecture.terminee) await _moteur.aller(Duration.zero);
        await _moteur.lire();
        _etat = EtatLecture.enCours;
      }
      _notifier();
    } catch (_) {
      _echec('La lecture a été interrompue.');
    }
  }

  /// Saute à une fraction de la durée (barre de progression).
  Future<void> chercher(double fraction) async {
    if (_ferme || _etat == EtatLecture.erreur || duree == Duration.zero) return;
    final cible = Duration(milliseconds: (duree.inMilliseconds * fraction.clamp(0.0, 1.0)).round());
    await _aller(cible);
  }

  /// Avance ou recule d'un nombre de secondes, borné au début et à la fin.
  Future<void> sauter(int secondes) async {
    if (_ferme || _etat == EtatLecture.erreur || _etat == EtatLecture.preparation) return;
    if (duree == Duration.zero) return;
    // Partir de la cible en cours, pas de l'ancienne position : plusieurs
    // appuis rapides s'additionnent au lieu de se chevaucher.
    var cible = position + Duration(seconds: secondes);
    if (cible < Duration.zero) cible = Duration.zero;
    if (cible > duree) cible = duree;
    await _aller(cible);
  }

  /// Saut unique pour toute l'application. Le dernier saut demandé gagne, la
  /// position exposée suit tout de suite la cible, et le moteur n'est repris
  /// comme référence qu'une fois arrivé (ou après un court délai de sécurité).
  Future<void> _aller(Duration cible) async {
    final numero = ++_numeroSaut;
    _cible = cible;
    _notifier();
    try {
      await _moteur.aller(cible);
    } catch (_) {
      if (numero == _numeroSaut) {
        _cible = null;
        _echec('Impossible de se déplacer dans ce contenu.');
      }
      return;
    }
    if (_ferme || numero != _numeroSaut) return;
    _armerFin(numero, cible);
    _notifier();
  }

  /// Rend la main au moteur quand sa position a rejoint la cible. Les
  /// moteurs (surtout sur le web) confirment le saut avec un léger retard :
  /// on attend qu'ils soient revenus à moins de 1,2 s de la cible, au plus 2,5 s.
  void _armerFin(int numero, Duration cible) {
    _filet?.cancel();
    final debut = DateTime.now();
    _filet = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (_ferme || numero != _numeroSaut) {
        t.cancel();
        return;
      }
      final ecart = (_moteur.position - cible).inMilliseconds.abs();
      final trop = DateTime.now().difference(debut) > const Duration(milliseconds: 2500);
      if (ecart <= 1200 || trop) {
        t.cancel();
        _cible = null;
        _notifier();
      }
    });
  }

  Future<void> regler(double valeur) async {
    _volume = valeur.clamp(0.0, 1.0);
    _notifier();
    try {
      await _moteur.volume(_volume);
    } catch (_) {}
  }

  /// Lance la lecture dès que le contenu est prêt (lecture automatique).
  Future<void> lancer() async {
    if (_ferme || _etat != EtatLecture.prete) return;
    await basculer();
  }

  /// Relance après une erreur réseau.
  Future<void> reessayer(String? source) => preparer(source);

  void _surChangement() {
    if (_ferme) return;
    if (_moteur.enErreur) {
      _echec(_moteur.messageErreur ?? 'La lecture a échoué.');
      return;
    }
    final fin = _cible == null && duree > Duration.zero && position >= duree;
    if (fin && _etat == EtatLecture.enCours) {
      _etat = EtatLecture.terminee;
    }
    _notifier();
  }

  void _echec(String message) {
    _etat = EtatLecture.erreur;
    _erreur = message;
    _notifier();
  }

  void _notifier() {
    if (!_ferme) notifyListeners();
  }

  static Uri? _sourceValide(String? source) {
    final texte = (source ?? '').trim();
    if (texte.isEmpty) return null;
    final uri = Uri.tryParse(texte);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  @override
  void dispose() {
    _ferme = true;
    _filet?.cancel();
    _moteur.fermer();
    super.dispose();
  }
}
