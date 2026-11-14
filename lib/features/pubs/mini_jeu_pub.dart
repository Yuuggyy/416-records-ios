import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Petit jeu d'attente pendant une pub : attraper les notes qui tombent.
///
/// Aucune règle compliquée : on touche une note pour marquer un point.
/// Le jeu s'arrête tout seul quand [actif] passe à faux.
class MiniJeuPub extends StatefulWidget {
  const MiniJeuPub({super.key, this.actif = true, this.graine});

  final bool actif;

  /// Graine du hasard, pour les tests.
  final int? graine;

  @override
  State<MiniJeuPub> createState() => _MiniJeuPubState();
}

class _Note {
  _Note(this.x, this.y, this.vitesse);
  double x; // 0..1
  double y; // 0..1
  final double vitesse;
}

class _MiniJeuPubState extends State<MiniJeuPub> {
  late final Random _hasard = Random(widget.graine);
  final List<_Note> _notes = [];
  Timer? _tic;
  int _points = 0;
  int _manquees = 0;
  int _meilleur = 0;
  int _compteur = 0;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(milliseconds: 40), (_) => _avancer());
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  void _avancer() {
    if (!mounted || !widget.actif) return;
    _compteur++;
    // Une nouvelle note toutes les ~0,8 s, de plus en plus vite avec les points.
    final cadence = max(10, 22 - _points ~/ 5);
    if (_compteur % cadence == 0) {
      _notes.add(_Note(0.08 + _hasard.nextDouble() * 0.84, -0.05, 0.006 + _hasard.nextDouble() * 0.004 + _points * 0.0001));
    }
    var perdues = 0;
    for (final n in _notes) {
      n.y += n.vitesse;
    }
    _notes.removeWhere((n) {
      if (n.y > 1.0) {
        perdues++;
        return true;
      }
      return false;
    });
    setState(() {
      _manquees += perdues;
    });
  }

  void _toucher(_Note n) {
    setState(() {
      _notes.remove(n);
      _points++;
      if (_points > _meilleur) _meilleur = _points;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final l = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            children: [
              for (final n in List<_Note>.from(_notes))
                Positioned(
                  left: n.x * (l - 44),
                  top: n.y * (h - 44),
                  child: GestureDetector(
                    key: ValueKey('note-${n.hashCode}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toucher(n),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.music_note, size: 32, color: Pal.primaireClaire),
                    ),
                  ),
                ),
              Positioned(
                left: Espace.m,
                top: Espace.s,
                child: Text('Notes attrapées : $_points', style: Typo.meta),
              ),
              Positioned(
                right: Espace.m,
                top: Espace.s,
                child: Text('Ratées : $_manquees', style: Typo.meta),
              ),
              if (_notes.isEmpty && _points == 0)
                const Center(
                  child: Text('Touche les notes avant qu\u2019elles tombent',
                      style: TextStyle(color: Pal.texteDoux, fontSize: 13)),
                ),
            ],
          );
        },
      ),
    );
  }
}
