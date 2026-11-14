import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

/// Pub vidéo récompensée via Unity LevelPlay.
///
/// Règles de sécurité :
/// - Sans identifiant d'emplacement (Ad Unit ID), le service reste inactif et
///   l'application se comporte comme avant : aucune pub, aucune erreur.
/// - Une panne publicitaire ne bloque JAMAIS l'application : tout est protégé.
/// - Le compte premium ne voit aucune pub : l'appelant vérifie `abonne`.
/// - Ne jamais cliquer sur de vraies pubs pendant les tests (risque de
///   suspension du compte). Utiliser la suite de test LevelPlay.
class ServiceLevelPlay
    with LevelPlayInitListener, LevelPlayRewardedAdListener {
  ServiceLevelPlay._();
  static final ServiceLevelPlay instance = ServiceLevelPlay._();

  /// App Key Android (LevelPlay). Surchargeable : `--dart-define=LEVELPLAY_APP_KEY=...`.
  static const String cleApplication =
      String.fromEnvironment('LEVELPLAY_APP_KEY', defaultValue: '2985809dd');

  /// Identifiant de l'ad unit « Reward ». Vide tant qu'il n'est pas fourni :
  /// `--dart-define=LEVELPLAY_REWARDED_ID=...`.
  static const String identifiantRecompense =
      String.fromEnvironment('LEVELPLAY_REWARDED_ID',
          defaultValue: 'cfogpcr0tmvuti87');

  /// Nom du placement (facultatif, sinon celui par défaut).
  static const String placement =
      String.fromEnvironment('LEVELPLAY_PLACEMENT', defaultValue: '');

  LevelPlayRewardedAd? _recompense;
  bool _initialise = false;
  bool _initEnCours = false;
  bool _prete = false;
  void Function()? _surRecompense;
  void Function(bool regardee)? _surFermeture;
  bool _recompenseObtenue = false;

  /// Faux sur le web et tant que l'identifiant d'emplacement est absent.
  bool get disponible =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      identifiantRecompense.isNotEmpty;

  bool get prete => _prete;

  /// À appeler une fois, sans attendre : n'échoue jamais.
  Future<void> initialiser({String? identifiantUtilisateur}) async {
    if (!disponible || _initialise || _initEnCours) return;
    _initEnCours = true;
    try {
      final requete = LevelPlayInitRequest.builder(cleApplication)
          .withUserId(identifiantUtilisateur ?? '')
          .build();
      await LevelPlay.init(initRequest: requete, initListener: this);
    } on PlatformException catch (e) {
      debugPrint('LevelPlay init: $e');
      _initEnCours = false;
    } catch (e) {
      debugPrint('LevelPlay init: $e');
      _initEnCours = false;
    }
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    _initialise = true;
    _initEnCours = false;
    _recompense = LevelPlayRewardedAd(adUnitId: identifiantRecompense)
      ..setListener(this);
    _charger();
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    _initEnCours = false;
    debugPrint('LevelPlay init échec: ${error.errorMessage}');
  }

  void _charger() {
    try {
      _prete = false;
      _recompense?.loadAd();
    } catch (e) {
      debugPrint('LevelPlay chargement: $e');
    }
  }

  /// Montre la vidéo si elle est prête. Retourne faux sinon (rien ne casse).
  /// [surRecompense] est appelé uniquement si la vidéo a été regardée en entier.
  Future<bool> montrer({required void Function() surRecompense}) async {
    final pub = _recompense;
    if (!disponible || !_initialise || pub == null) return false;
    try {
      if (!await pub.isAdReady()) {
        _charger();
        return false;
      }
      _surRecompense = surRecompense;
      await pub.showAd(placementName: placement.isEmpty ? null : placement);
      return true;
    } catch (e) {
      debugPrint('LevelPlay affichage: $e');
      return false;
    }
  }

  /// Charge la pub si besoin (sans rien afficher). Utile pendant le mini-jeu.
  void preparer() {
    if (!disponible || !_initialise || _prete) return;
    _charger();
  }

  /// Montre la pub et rappelle [surFin] à sa fermeture :
  /// vrai si elle a été regardée jusqu'à la récompense, faux sinon.
  /// Retourne faux tout de suite si aucune pub n'est prête (rien ne casse).
  Future<bool> montrerAvecFin({required void Function(bool regardee) surFin}) async {
    final pub = _recompense;
    if (!disponible || !_initialise || pub == null) return false;
    try {
      if (!await pub.isAdReady()) {
        _charger();
        return false;
      }
      _recompenseObtenue = false;
      _surFermeture = surFin;
      await pub.showAd(placementName: placement.isEmpty ? null : placement);
      return true;
    } catch (e) {
      debugPrint('LevelPlay affichage: $e');
      _surFermeture = null;
      return false;
    }
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _prete = true;

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    _prete = false;
    debugPrint('LevelPlay chargement échec: ${error.errorMessage}');
  }

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _recompenseObtenue = true;
    final action = _surRecompense;
    _surRecompense = null;
    action?.call();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    final fin = _surFermeture;
    _surFermeture = null;
    final regardee = _recompenseObtenue;
    _recompenseObtenue = false;
    _charger();
    fin?.call(regardee);
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _surRecompense = null;
    final fin = _surFermeture;
    _surFermeture = null;
    _charger();
    fin?.call(false);
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}
