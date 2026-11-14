import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';
import '../../data/moteur_video_plugin.dart';
import '../../state/controleur_lecture.dart';

/// Une version audio d'un morceau (ex. « Super fan » ou « Compressée »).
class QualiteAudio {
  const QualiteAudio(this.libelle, this.url);

  final String libelle;
  final String? url;
}

/// Lecteur plein écran pour un film ou un morceau.
///
/// La lecture démarre toute seule dès que le contenu est prêt. Les commandes
/// (reculer/avancer de 15 s, lecture/pause au centre, volume, plein écran)
/// se masquent d'un toucher pendant la lecture et reviennent d'un autre.
///
/// L'adresse du flux reste dans ce fichier et dans le moteur : elle n'est
/// jamais affichée ni copiable par l'utilisateur.
class LecteurScreen extends StatefulWidget {
  const LecteurScreen({
    super.key,
    required this.titre,
    required this.source,
    this.sousTitre,
    this.audioSeul = false,
    this.qualites = const [],
    this.moteur,
  });

  final String titre;
  final String? sousTitre;
  final String? source;
  final bool audioSeul;

  /// Si deux versions ou plus existent, l'utilisateur choisit sa qualité.
  final List<QualiteAudio> qualites;

  /// Moteur injectable pour les tests ; le plugin réel par défaut.
  final MoteurLecture? moteur;

  @override
  State<LecteurScreen> createState() => _LecteurScreenState();
}

class _LecteurScreenState extends State<LecteurScreen> {
  late final MoteurLecture _moteur = widget.moteur ?? MoteurVideoPlugin();
  late final ControleurLecture _lecture = ControleurLecture(moteur: _moteur);

  static const _saut = 15;

  late String? _source = widget.source;
  int _qualite = 0;
  bool _commandes = true;
  bool _plein = false;
  Timer? _masquage;

  /// Délai sans toucher avant que les commandes disparaissent (pendant la lecture).
  static const _delaiMasquage = Duration(milliseconds: 3500);

  bool get _video => !widget.audioSeul;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    await _lecture.preparer(_source);
    if (!mounted) return;
    await _lecture.lancer();
    _programmerMasquage();
  }

  /// Les commandes se retirent seules après quelques secondes de lecture :
  /// l'écran reste à la vidéo. En pause, elles restent affichées.
  void _programmerMasquage() {
    _masquage?.cancel();
    if (!_commandes) return;
    _masquage = Timer(_delaiMasquage, () {
      if (mounted && _lecture.enLecture) setState(() => _commandes = false);
    });
  }

  void _toucherEcran() {
    setState(() => _commandes = !_commandes);
    _programmerMasquage();
  }

  /// Toute action sur une commande prolonge son affichage.
  void _commandeUtilisee() => _programmerMasquage();

  Future<void> _changerQualite(int i) async {
    if (i == _qualite) return;
    final reprise = _lecture.position;
    setState(() {
      _qualite = i;
      _source = widget.qualites[i].url;
    });
    await _lecture.preparer(_source);
    if (!mounted) return;
    if (_lecture.duree > Duration.zero) {
      await _lecture.chercher(
        (reprise.inMilliseconds / _lecture.duree.inMilliseconds).clamp(0.0, 1.0),
      );
    }
    await _lecture.lancer();
    _programmerMasquage();
  }

  Future<void> _basculerPleinEcran() async {
    final entrer = !_plein;
    setState(() => _plein = entrer);
    if (entrer) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await _rendreEcran();
    }
  }

  Future<void> _rendreEcran() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _masquage?.cancel();
    if (_plein) _rendreEcran();
    _lecture.dispose();
    super.dispose();
  }

  String _horloge(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Widget _image() {
    final moteur = _moteur;
    if (widget.audioSeul || moteur is! MoteurVideoPlugin || moteur.controleur == null) {
      return Center(
        child: Icon(
          widget.audioSeul ? Icons.graphic_eq : Icons.movie_outlined,
          size: 64,
          color: Pal.texteDoux,
        ),
      );
    }
    final c = moteur.controleur!;
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.isInitialized && c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _erreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Pal.danger, size: 40),
            const SizedBox(height: Espace.m),
            Text(
              _lecture.erreur ?? 'La lecture a échoué.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: Espace.m),
            OutlinedButton(
              onPressed: () async {
                await _lecture.reessayer(_source);
                if (mounted) await _lecture.lancer();
              },
              child: const Text('RÉESSAYER'),
            ),
          ],
        ),
      ),
    );
  }

  /// Boutons centraux : reculer 15 s, lecture/pause, avancer 15 s.
  Widget _boutonsCentraux() {
    Widget saut(IconData icone, String info, int secondes) => IconButton(
          iconSize: 36,
          tooltip: info,
          color: Colors.white,
          onPressed: () {
            _lecture.sauter(secondes);
            _commandeUtilisee();
          },
          icon: Icon(icone),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        saut(Icons.replay, 'Reculer de $_saut secondes', -_saut),
        const SizedBox(width: Espace.l),
        IconButton(
          iconSize: 68,
          tooltip: _lecture.enLecture ? 'Pause' : 'Lire',
          onPressed: () {
            _lecture.basculer();
            _commandeUtilisee();
          },
          icon: Icon(
            _lecture.enLecture ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: Pal.primaire,
          ),
        ),
        const SizedBox(width: Espace.l),
        saut(Icons.fast_forward, 'Avancer de $_saut secondes', _saut),
      ],
    );
  }

  Widget _barreBasse() {
    return Container(
      padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.s, Espace.s),
      color: Colors.black.withAlpha(150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _lecture.progression,
            onChanged: (v) {
              _lecture.chercher(v);
              _commandeUtilisee();
            },
          ),
          Row(
            children: [
              Text('${_horloge(_lecture.position)} / ${_horloge(_lecture.duree)}', style: Typo.meta),
              const Spacer(),
              Icon(
                _lecture.volume == 0 ? Icons.volume_off : Icons.volume_up,
                size: 18,
                color: Pal.texteDoux,
              ),
              SizedBox(
                width: 110,
                child: Slider(
                  value: _lecture.volume,
                  onChanged: (v) {
                    _lecture.regler(v);
                    _commandeUtilisee();
                  },
                ),
              ),
              if (_video)
                IconButton(
                  tooltip: _plein ? 'Quitter le plein écran' : 'Plein écran',
                  onPressed: _basculerPleinEcran,
                  icon: Icon(_plein ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Flèche de retour et titre : par-dessus la vidéo, visibles seulement avec les commandes.
  Widget _barreHaute() {
    return Container(
      padding: const EdgeInsets.fromLTRB(Espace.xs, Espace.xs, Espace.m, Espace.s),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withAlpha(190), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            color: Colors.white,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              widget.titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Choix de la qualité, posé sur la vidéo avec les autres commandes.
  Widget _choixQualite() {
    if (widget.qualites.length < 2) return const SizedBox.shrink();
    return Container(
      color: Colors.black.withAlpha(150),
      padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, 0),
      child: Row(
        children: [
          const Text('QUALITÉ', style: Typo.etiquette),
          const SizedBox(width: Espace.m),
          Expanded(
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < widget.qualites.length; i++)
                  ButtonSegment<int>(value: i, label: Text(widget.qualites[i].libelle)),
              ],
              selected: {_qualite},
              onSelectionChanged: (s) {
                _changerQualite(s.first);
                _commandeUtilisee();
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        if (_plein) _rendreEcran();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _lecture,
            builder: (context, _) {
              final etat = _lecture.etat;
              final montrer = _commandes || !_lecture.enLecture;
              return switch (etat) {
                EtatLecture.preparation => Stack(
                    fit: StackFit.expand,
                    children: [
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      Align(alignment: Alignment.topCenter, child: _barreHaute()),
                    ],
                  ),
                EtatLecture.erreur => Stack(
                    fit: StackFit.expand,
                    children: [
                      _erreur(),
                      Align(alignment: Alignment.topCenter, child: _barreHaute()),
                    ],
                  ),
                _ => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toucherEcran,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _image(),
                        // Rien d'autre que la vidéo tant qu'on ne touche pas l'écran.
                        if (montrer) Align(alignment: Alignment.topCenter, child: _barreHaute()),
                        if (montrer) Center(child: _boutonsCentraux()),
                        if (montrer)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [_choixQualite(), _barreBasse()],
                            ),
                          ),
                      ],
                    ),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}
