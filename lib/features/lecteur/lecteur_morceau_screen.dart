import 'package:flutter/material.dart';

import '../../core/liens_ecoute.dart';
import '../../core/scope.dart';
import '../../core/paroles.dart';
import '../../core/widgets/panneau_plateformes.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../data/moteur_video_plugin.dart';
import '../../state/controleur_lecture.dart';
import '../pubs/choix_super_fan.dart';
import '../pubs/duree_pub.dart';
import 'lecteur_screen.dart' show QualiteAudio;
import 'vue_paroles.dart';

/// Lecteur de morceau : pochette, progression, commandes et paroles qui
/// défilent en rythme quand elles sont horodatées (format LRC).
///
/// La lecture démarre seule. L'adresse du fichier reste dans ce fichier et
/// dans le moteur : elle n'est jamais affichée.
class LecteurMorceauScreen extends StatefulWidget {
  const LecteurMorceauScreen({
    super.key,
    required this.titre,
    required this.artiste,
    required this.qualites,
    this.posterUrl,
    this.paroles,
    this.moteur,
    this.liens = const [],
  });

  /// Plateformes où ce morceau existe (vide : le bouton n'apparait pas).
  final List<LienEcoute> liens;

  final String titre;
  final String artiste;
  final String? posterUrl;

  /// Au moins une version ; la première est lue au départ.
  final List<QualiteAudio> qualites;
  final String? paroles;

  /// Moteur injectable pour les tests ; le plugin réel par défaut.
  final MoteurLecture? moteur;

  @override
  State<LecteurMorceauScreen> createState() => _LecteurMorceauScreenState();
}

class _LecteurMorceauScreenState extends State<LecteurMorceauScreen> {
  late final MoteurLecture _moteur = widget.moteur ?? MoteurVideoPlugin();
  late final ControleurLecture _lecture = ControleurLecture(moteur: _moteur);
  late final Paroles _paroles = Paroles.analyser(widget.paroles);

  static const _saut = 15;

  int _qualite = 0;
  bool _voirParoles = false;
  bool _superFanDebloque = false;

  String? get _source => widget.qualites.isEmpty ? null : widget.qualites[_qualite].url;

  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demarre) return;
    _demarre = true;
    _demarrer();
  }

  Future<void> _demarrer() async {
    // Sans catalogue (écran isolé), aucun contrôle d'abonnement : comportement d'origine.
    final catalogue = context.getInheritedWidgetOfExactType<CatalogueScope>();
    final abonne = catalogue == null || catalogue.abonnement.abonne;
    final i = widget.qualites.indexWhere((q) => q.libelle != 'Super fan');
    if (!abonne && widget.qualites[_qualite].libelle == 'Super fan' && i >= 0) {
      setState(() => _qualite = i);
    }
    await _lecture.preparer(_source);
    if (!mounted) return;
    await _lecture.lancer();
  }

  Future<void> _changerQualite(int i) async {
    if (i == _qualite) return;
    // « Super fan » : réservé aux abonnés, ou à ceux qui regardent une pub.
    if (widget.qualites[i].libelle == 'Super fan' && !_superFanDebloque) {
      // demanderSuperFan laisse passer abonnés et écrans sans catalogue.
      final jouait = _lecture.enLecture;
      if (jouait) await _lecture.basculer();
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final res = await demanderSuperFan(context, type: TypeContenu.son);
      if (!mounted) return;
      if (res == ChoixSuperFan.annule) {
        if (jouait) await _lecture.lancer();
        return;
      }
      _superFanDebloque = true;
    }
    final reprise = _lecture.position;
    setState(() => _qualite = i);
    await _lecture.preparer(_source);
    if (!mounted) return;
    if (_lecture.duree > Duration.zero) {
      await _lecture.chercher(
        (reprise.inMilliseconds / _lecture.duree.inMilliseconds).clamp(0.0, 1.0),
      );
    }
    await _lecture.lancer();
  }

  @override
  void dispose() {
    _lecture.dispose();
    super.dispose();
  }

  String _horloge(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  Widget _pochette(double cote) {
    final url = widget.posterUrl;
    return Container(
      width: cote,
      height: cote,
      decoration: BoxDecoration(
        color: Pal.surfaceHaute,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url.trim().isEmpty)
          ? const Icon(Icons.music_note, size: 72, color: Pal.texteDoux)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 72, color: Pal.texteDoux),
            ),
    );
  }

  Widget _vueParoles() {
    if (_paroles.vide) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Espace.l),
          child: Text('Pas de paroles pour ce morceau.',
              textAlign: TextAlign.center, style: TextStyle(color: Pal.texteDoux, fontSize: 14)),
        ),
      );
    }
    return VueParoles(
      paroles: _paroles,
      ligneActive: _paroles.indiceA(_lecture.position),
      onChercher: (debut) {
        final d = _lecture.duree.inMilliseconds;
        if (d > 0) _lecture.chercher(debut.inMilliseconds / d);
      },
    );
  }

  Widget _commandes() {
    Widget saut(IconData icone, String info, int secondes) => IconButton(
          iconSize: 34,
          tooltip: info,
          color: Pal.texte,
          onPressed: () => _lecture.sauter(secondes),
          icon: Icon(icone),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        saut(Icons.replay, 'Reculer de $_saut secondes', -_saut),
        const SizedBox(width: Espace.m),
        IconButton(
          iconSize: 72,
          tooltip: _lecture.enLecture ? 'Pause' : 'Lire',
          onPressed: _lecture.basculer,
          icon: Icon(
            _lecture.enLecture ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: Pal.primaire,
          ),
        ),
        const SizedBox(width: Espace.m),
        saut(Icons.fast_forward, 'Avancer de $_saut secondes', _saut),
      ],
    );
  }

  Widget _choixQualite() {
    if (widget.qualites.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Espace.s),
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          for (var i = 0; i < widget.qualites.length; i++)
            ButtonSegment<int>(value: i, label: Text(widget.qualites[i].libelle)),
        ],
        selected: {_qualite},
        onSelectionChanged: (s) => _changerQualite(s.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _bas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espace.l, 0, Espace.l, Espace.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _choixQualite(),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
            child: Slider(value: _lecture.progression, onChanged: _lecture.chercher),
          ),
          Row(
            children: [
              Text(_horloge(_lecture.position), style: const TextStyle(fontSize: 11, color: Pal.texteDoux)),
              const Spacer(),
              Text(_horloge(_lecture.duree), style: const TextStyle(fontSize: 11, color: Pal.texteDoux)),
            ],
          ),
          const SizedBox(height: Espace.xs),
          _commandes(),
          Row(
            children: [
              Icon(_lecture.volume == 0 ? Icons.volume_off : Icons.volume_up, size: 18, color: Pal.texteDoux),
              Expanded(child: Slider(value: _lecture.volume, onChanged: _lecture.regler)),
              if (widget.liens.isNotEmpty)
                IconButton(
                  key: const ValueKey('autres-plateformes'),
                  tooltip: 'Écouter sur d\'autres plateformes',
                  onPressed: () => montrerPlateformes(context, titre: widget.titre, liens: widget.liens),
                  icon: const Icon(Icons.headphones_outlined, color: Pal.texteDoux),
                ),
              IconButton(
                tooltip: _voirParoles ? 'Masquer les paroles' : 'Afficher les paroles',
                onPressed: () => setState(() => _voirParoles = !_voirParoles),
                icon: Icon(
                  Icons.lyrics_outlined,
                  color: _voirParoles ? Pal.primaire : Pal.texteDoux,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entete(double cote) {
    return Row(
      children: [
        _pochette(cote),
        const SizedBox(width: Espace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titre, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(widget.artiste, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Pal.texteDoux)),
            ],
          ),
        ),
      ],
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
            Text(_lecture.erreur ?? 'La lecture a échoué.', textAlign: TextAlign.center),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.fond,
      appBar: AppBar(
        backgroundColor: Pal.fond,
        surfaceTintColor: Colors.transparent,
        title: const Text('Lecture', style: TextStyle(fontSize: 14, letterSpacing: 1.4)),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _lecture,
          builder: (context, _) {
            if (_lecture.etat == EtatLecture.erreur) return _erreur();
            if (_lecture.etat == EtatLecture.preparation) return const EtatChargement(message: 'Chargement du morceau…');
            final largeur = MediaQuery.of(context).size.width;
            final grande = (largeur - Espace.l * 2).clamp(180.0, 340.0);
            return Column(
              children: [
                Expanded(
                  child: _voirParoles
                      ? Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(Espace.l, Espace.s, Espace.l, 0),
                              child: _entete(56),
                            ),
                            Expanded(child: _vueParoles()),
                          ],
                        )
                      : LayoutBuilder(
                          builder: (context, c) {
                            // La pochette s'adapte à la place restante (petits écrans, mode paysage).
                            const reserve = 110.0;
                            final cote = (c.maxHeight - reserve).clamp(0.0, grande);
                            return Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (cote >= 80) ...[
                                      _pochette(cote),
                                      const SizedBox(height: Espace.m),
                                    ],
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: Espace.l),
                                      child: Column(
                                        children: [
                                          Text(widget.titre,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(widget.artiste,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 14, color: Pal.texteDoux)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Flexible(flex: 0, child: SingleChildScrollView(child: _bas())),
              ],
            );
          },
        ),
      ),
    );
  }
}
