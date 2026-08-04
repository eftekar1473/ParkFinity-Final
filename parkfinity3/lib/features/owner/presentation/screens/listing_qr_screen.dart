import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/listing_model.dart';
import '../../../parking/data/qr_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The poster an owner prints and mounts at the spot. Riders scan it to check in
/// and out. The token comes from the server (`listings.qr_token`) and never
/// changes, so a printed sheet stays valid for the life of the listing.
class ListingQrScreen extends StatelessWidget {
  final ListingModel listing;
  const ListingQrScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final token = listing.qrToken;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spotQrCode)),
      body: token == null
          ? Center(child: Text(l10n.somethingWentWrong))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  listing.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.address,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor),
                ),
                const SizedBox(height: 24),

                // White backing regardless of theme: scanners need the contrast,
                // and a dark-mode QR on a dark card will not read.
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: QrImageView(
                      data: '${QrRepository.scheme}$token',
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (listing.qrShortCode != null) ...[
                  Center(child: Text(l10n.shortCode,
                      style: TextStyle(color: theme.hintColor))),
                  const SizedBox(height: 4),
                  Center(
                    child: SelectableText(
                      listing.qrShortCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.printAndMountQr)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.scanToStart,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                ),
              ],
            ),
    );
  }
}
