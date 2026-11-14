import 'package:flutter/widgets.dart';

/// Hors navigateur : le bouton Google natif n'existe pas, l'écran garde son
/// propre bouton (Android passe par signIn avec serverClientId).
Widget boutonGoogleOfficiel() => const SizedBox.shrink();
