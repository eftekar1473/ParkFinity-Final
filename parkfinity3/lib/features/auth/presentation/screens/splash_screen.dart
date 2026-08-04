import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// Shown while the router resolves the session and profile. The redirect logic
/// in app_router decides where to go next, so this screen only has to look
/// deliberate for the fraction of a second it is on screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_parking,
                size: 96, color: theme.colorScheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).appTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: theme.colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
