import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/scheduler.dart';

import '../../core/paroles.dart';
import '../../core/theme.dart';

/// Paroles façon Apple Music : la ligne chantée est grande, centrée et nette ;
/// les autres s'estompent et se floutent avec la distance. Chaque ligne prend
/// la hauteur dont elle a besoin (les phrases longues passent sur plusieurs
/// lignes sans se chevaucher), et la vue suit la lecture avec un défilement doux.
///
/// Si la personne fait défiler à la main, le suivi automatique se met en pause
/// quelques secondes puis reprend.
class VueParoles extends StatefulWidget {
  const VueParoles({
    super.key,
    required this.paroles,
    required this.ligneActive,
    required this.onChercher,
  });

  final Paroles paroles;

  /// Indice de la ligne en cours (-1 avant la première), ignoré hors synchro.
  final int ligneActive;

  /// Appelé quand on touche une ligne synchronisée.
  final ValueChanged<Duration> onChercher;

  @override
  State<VueParoles> createState() => _VueParolesState();
}

class _VueParolesState extends State<VueParoles> {
  final ScrollController _defilement = ScrollController();
  late List<GlobalKey> _cles = _fabriquerCles();
  Timer? _reprise;
  bool _mainLibre = false;
  bool _premiereFois = true;

  List<GlobalKey> _fabriquerCles() =>
      List.generate(widget.paroles.lignes.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(VueParoles ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.paroles != widget.paroles) _cles = _fabriquerCles();
    if (ancien.ligneActive != widget.ligneActive) {
      // Un saut de plusieurs lignes (barre, touche sur une ligne) se fait sans
      // animation longue : une animation de 520 ms en cours serait sinon
      // écrasée par la suivante et la vue finirait sur la mauvaise ligne.
      final saut = (widget.ligneActive - ancien.ligneActive).abs() > 1;
      _centrer(immediat: saut);
    }
  }

  @override
  void initState() {
    super.initState();
    _centrer();
  }

  @override
  void dispose() {
    _reprise?.cancel();
    _defilement.dispose();
    super.dispose();
  }

  /// Centre la ligne active : on attend la fin du rendu pour lire sa vraie
  /// position, puisque la hauteur de chaque ligne dépend de son texte.
  int _generation = 0;

  void _centrer({bool immediat = false, bool force = false}) {
    if (!widget.paroles.synchronisees) return;
    if (_mainLibre && !force) return;
    final generation = ++_generation;
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_defilement.hasClients) return;
      // Une demande plus récente a pris le relais : on ne l'écrase pas.
      if (generation != _generation) return;
      // La ligne à centrer est toujours celle d'AUJOURD'HUI, pas celle du moment de la demande.
      final i = widget.ligneActive;
      if (i < 0 || i >= _cles.length) {
        if (i < 0 && _defilement.offset > 0) {
          _defilement.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
        }
        return;
      }
      final ctx = _cles[i].currentContext;
      if (ctx == null) return;
      final boite = ctx.findRenderObject() as RenderBox?;
      final liste = _defilement.position.context.storageContext.findRenderObject() as RenderBox?;
      if (boite == null || liste == null || !boite.attached) return;
      final haut = boite.localToGlobal(Offset.zero, ancestor: liste).dy;
      final cible = (_defilement.offset + haut + boite.size.height / 2 - liste.size.height * 0.38)
          .clamp(0.0, _defilement.position.maxScrollExtent);
      if (_premiereFois || immediat) {
        _premiereFois = false;
        _defilement.jumpTo(cible);
      } else {
        _defilement.animateTo(cible,
            duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
      }
    });
  }

  void _mainPosee() {
    _reprise?.cancel();
    _mainLibre = true;
  }

  void _mainLevee() {
    _reprise?.cancel();
    _reprise = Timer(const Duration(seconds: 4), () {
      _mainLibre = false;
      if (mounted) _centrer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paroles;
    final sync = p.synchronisees;
    return LayoutBuilder(builder: (context, c) {
      // Taille adaptée à la largeur : confortable sur téléphone, mesurée sur tablette et web.
      final base = (c.maxWidth * 0.058).clamp(20.0, 30.0);
      final marge = (c.maxWidth * 0.07).clamp(16.0, 56.0);
      final largeurTexte = c.maxWidth.clamp(0.0, 720.0);
      return Listener(
        onPointerDown: (_) => _mainPosee(),
        onPointerUp: (_) => _mainLevee(),
        onPointerCancel: (_) => _mainLevee(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Molette / défilement par glissement sur le web.
            if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
              _mainPosee();
              _mainLevee();
            }
            return false;
          },
          child: ShaderMask(
            // Fondu en haut et en bas, comme les paroles d'Apple Music.
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.08, 0.9, 1.0],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              controller: _defilement,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.symmetric(vertical: c.maxHeight * 0.38, horizontal: marge),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: largeurTexte),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < p.lignes.length; i++)
                        KeyedSubtree(
                          key: _cles[i],
                          child: _Ligne(
                            texte: p.lignes[i].texte,
                            taille: base,
                            etat: !sync
                                ? _Etat.simple
                                : i == widget.ligneActive
                                    ? _Etat.active
                                    : i < widget.ligneActive
                                        ? _Etat.passee
                                        : _Etat.avenir,
                            ecart: sync && widget.ligneActive >= 0 ? (i - widget.ligneActive).abs() : 0,
                            onTap: sync
                                ? () {
                                    // Le toucher rend la main au suivi automatique.
                                    _reprise?.cancel();
                                    _mainLibre = false;
                                    widget.onChercher(p.lignes[i].debut!);
                                    _centrer(immediat: true, force: true);
                                  }
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

enum _Etat { simple, active, passee, avenir }

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.texte,
    required this.taille,
    required this.etat,
    required this.ecart,
    this.onTap,
  });

  final String texte;
  final double taille;
  final _Etat etat;
  final int ecart;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = etat == _Etat.active;
    final simple = etat == _Etat.simple;
    // Flou progressif : 0 pour la ligne active, jusqu'à 2,4 pour les plus éloignées.
    final flou = (simple || active) ? 0.0 : (ecart * 0.8).clamp(0.0, 2.4);
    final opacite = simple
        ? 1.0
        : active
            ? 1.0
            : (0.62 - ecart * 0.1).clamp(0.22, 0.62);

    Widget texteLigne = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      style: TextStyle(
        fontSize: taille,
        fontWeight: FontWeight.w800,
        height: 1.28,
        letterSpacing: -0.2,
        color: active || simple ? Pal.texte : Pal.texte.withOpacity(opacite),
      ),
      child: Text(texte, softWrap: true),
    );

    if (flou > 0.05) {
      texteLigne = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: flou, sigmaY: flou, tileMode: TileMode.decal),
        child: texteLigne,
      );
    }

    return Semantics(
      button: onTap != null,
      label: texte,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.transparent,
        highlightColor: Pal.primaire.withOpacity(0.10),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          // Espacement généreux entre deux phrases : une ligne longue ne colle plus la suivante.
          padding: EdgeInsets.symmetric(vertical: simple ? taille * 0.34 : taille * 0.46, horizontal: 2),
          child: AnimatedScale(
            scale: active ? 1.0 : 0.92,
            alignment: Alignment.centerLeft,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: texteLigne,
          ),
        ),
      ),
    );
  }
}
