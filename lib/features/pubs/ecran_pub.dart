import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/service_levelplay.dart';
import 'mini_jeu_pub.dart';

/// Abstraction de la régie, pour pouvoir tester sans téléphone.
abstract class RegiePub {
  bool get disponible;
  bool get prete;
  void preparer();
  Future<bool> montrer(void Function(bool regardee) surFin);
}

class RegieLevelPlay implements RegiePub {
  const RegieLevelPlay();
  @override
  bool get disponible => ServiceLevelPlay.instance.disponible;
  @override
  bool get prete => ServiceLevelPlay.instance.prete;
  @override
  void preparer() => ServiceLevelPlay.instance.preparer();
  @override
  Future<bool> montrer(void Function(bool regardee) surFin) =>
      ServiceLevelPlay.instance.montrerAvecFin(surFin: surFin);
}

/// Écran « pub » du label.
///
/// Déroulé : un mini-jeu occupe l'attente pendant que la pub de la régie
/// (LevelPlay) se charge, puis la vidéo de la régie s'affiche en plein écran.
/// À sa fin, l'écran se ferme avec `true` et le contenu démarre.
///
/// Aucun annonceur du label n'est affiché ici : seules les pubs de la régie.
/// Si la régie n'a aucune pub à montrer, ou n'est pas disponible, un compte
/// à rebours de [dureeSecondes] avec le mini-jeu prend le relais : l'écran
/// ne bloque jamais l'utilisateur.
/// Se ferme avec `false` si l'utilisateur renonce avant la fin.
class EcranPub extends StatefulWidget {
  const EcranPub({
    super.key,
    required this.dureeSecondes,
    this.regie = const RegieLevelPlay(),
    this.attenteRegie = const Duration(seconds: 6),
    this.jeu = true,
  });

  final int dureeSecondes;
  final RegiePub regie;

  /// Temps laissé à la régie pour charger sa pub avant le repli.
  final Duration attenteRegie;
  final bool jeu;

  @override
  State<EcranPub> createState() => _EcranPubState();
}

enum _Phase { chargement, regie, repli }

class _EcranPubState extends State<EcranPub> {
  late int _restant = widget.dureeSecondes;
  Timer? _tic;
  Timer? _sonde;
  _Phase _phase = _Phase.chargement;
  bool _sortieLibre = false;
  int _attenteEcoulee = 0; // en demi-secondes

  @override
  void initState() {
    super.initState();
    if (!widget.regie.disponible) {
      _passerEnRepli();
      return;
    }
    widget.regie.preparer();
    // Toutes les 500 ms : la pub est-elle prête ? Sinon, repli après le délai.
    _sonde = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      if (!mounted || _phase != _Phase.chargement) {
        t.cancel();
        return;
      }
      if (widget.regie.prete) {
        t.cancel();
        await _lancerRegie();
      } else if (++_attenteEcoulee * 500 >= widget.attenteRegie.inMilliseconds) {
        t.cancel();
        _passerEnRepli();
      }
    });
  }

  Future<void> _lancerRegie() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.regie);
    final ok = await widget.regie.montrer((regardee) {
      if (!mounted) return;
      if (regardee) {
        _fermer(true);
      } else {
        // Pub fermée avant la fin : on ne récompense pas.
        _fermer(false);
      }
    });
    if (!ok && mounted && _phase == _Phase.regie) _passerEnRepli();
  }

  void _passerEnRepli() {
    if (!mounted) return;
    setState(() => _phase = _Phase.repli);
    _tic = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restant <= 1) {
        t.cancel();
        _fermer(true);
      } else {
        setState(() => _restant--);
      }
    });
  }

  void _fermer(bool resultat) {
    if (_sortieLibre) return;
    _sortieLibre = true;
    Navigator.of(context).pop(resultat);
  }

  @override
  void dispose() {
    _tic?.cancel();
    _sonde?.cancel();
    super.dispose();
  }

  Future<void> _renoncer() async {
    if (_sortieLibre) return;
    final sortir = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitter la pub ?'),
        content: const Text('Si tu quittes maintenant, le contenu ne se lance pas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('RESTER')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('QUITTER')),
        ],
      ),
    );
    if (sortir == true && mounted) _fermer(false);
  }

  @override
  Widget build(BuildContext context) {
    final repli = _phase == _Phase.repli;
    final progression = repli ? 1 - (_restant / widget.dureeSecondes) : null;
    return PopScope(
      canPop: _sortieLibre,
      onPopInvokedWithResult: (sorti, _) {
        if (!sorti) _renoncer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Espace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Pal.texteDoux),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('PUB', style: TextStyle(fontSize: 11, color: Pal.texteDoux)),
                    ),
                    const Spacer(),
                    if (repli) Text('$_restant s', key: const ValueKey('reste'), style: Typo.meta),
                    IconButton(
                      tooltip: 'Quitter',
                      onPressed: _renoncer,
                      icon: const Icon(Icons.close, color: Pal.texteDoux, size: 20),
                    ),
                  ],
                ),
                LinearProgressIndicator(value: progression, minHeight: 3),
                const SizedBox(height: Espace.m),
                if (widget.jeu)
                  const Expanded(child: MiniJeuPub())
                else
                  const Spacer(),
                const SizedBox(height: Espace.s),
                Text(
                  repli
                      ? 'Un jeu pour patienter. Le contenu démarre à la fin du compte à rebours.'
                      : 'La pub arrive. Joue en attendant, le contenu démarre juste après.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Pal.texteDoux, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
