import 'package:flutter/foundation.dart';

import 'web/contexte_web.dart';

/// Où l'application tourne, pour que le robot Telegram ramène la personne au
/// bon endroit : `apk` (Android installé), `ios`, `pwa` (site ajouté à
/// l'écran d'accueil) ou `web` (navigateur).
///
/// Indication d'affichage uniquement : le serveur ne s'en sert jamais pour
/// décider d'un accès.
String contexteAppareil({
  bool? estWeb,
  TargetPlatform? plateforme,
  bool Function()? installe,
}) {
  final web = estWeb ?? kIsWeb;
  if (web) return (installe ?? webInstalle)() ? 'pwa' : 'web';
  switch (plateforme ?? defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'apk';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'web';
  }
}
