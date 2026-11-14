import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Navigateur : le bouton officiel de Google (Google Identity Services).
/// C'est la seule voie qui rend un jeton d'identité fiable sur le web ;
/// `signIn()` est abandonné par Google pour cet usage.
Widget boutonGoogleOfficiel() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.continueWith,
        shape: web.GSIButtonShape.rectangular,
        minimumWidth: 320,
      ),
    );
