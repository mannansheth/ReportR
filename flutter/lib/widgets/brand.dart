import 'package:flutter/material.dart';
import '../l10n/ui_strings.dart';

/// The unmodified logo used by the original React Native app and Expo splash.
class ReportRLogo extends StatelessWidget {
  const ReportRLogo({super.key, this.size = 96});
  static const asset = 'assets/branding/logo.png';
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'ReportR',
  );
}

/// Matches the thin green rotating progress indicator from the original app.
class ReportRLoader extends StatelessWidget {
  const ReportRLoader({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: const Color(0xFF4CAF50),
      backgroundColor: Colors.black12,
      semanticsLabel: UiStrings.of(context).text('Loading...'),
    ),
  );
}

class BrandStartupScreen extends StatelessWidget {
  const BrandStartupScreen({super.key, this.error, this.onRetry});
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReportRLogo(size: 180),
            const SizedBox(height: 24),
            if (error == null)
              const ReportRLoader()
            else ...[
              Text(
                UiStrings.of(
                  context,
                ).text('Unable to start the app. Please try again.'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: Text(UiStrings.of(context).text('Try again')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
