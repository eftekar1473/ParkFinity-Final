import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models/listing_model.dart';
import '../../../parking/data/qr_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// The poster an owner prints and mounts at the spot. Riders scan it to check in
/// and out. The token comes from the server (`listings.qr_token`) and never
/// changes, so a printed sheet stays valid for the life of the listing.
class ListingQrScreen extends StatefulWidget {
  final ListingModel listing;
  const ListingQrScreen({super.key, required this.listing});

  @override
  State<ListingQrScreen> createState() => _ListingQrScreenState();
}

class _ListingQrScreenState extends State<ListingQrScreen> {
  bool _saving = false;

  /// Paint the QR straight to a PNG (no widget capture needed) and drop it in
  /// the phone gallery. High resolution so a printed copy stays crisp.
  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    final token = widget.listing.qrToken;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final painter = QrPainter(
        data: '${QrRepository.scheme}$token',
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Color(0xFF000000)),
      );
      // Render on a white canvas so scanners get contrast in any theme.
      const size = 1024.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      const pad = 64.0;
      painter.paint(canvas, const Size(size - pad * 2, size - pad * 2));
      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('encode failed');

      final safeName = widget.listing.qrShortCode ??
          widget.listing.title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
      await Gal.putImageBytes(bytes.buffer.asUint8List(),
          name: 'ParkFinity_QR_$safeName');

      if (!mounted) return;
      _snack(l10n.qrSavedToGallery, error: false);
    } catch (e) {
      if (!mounted) return;
      _snack('${l10n.qrSaveFailed} $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? Theme.of(context).colorScheme.error : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listing = widget.listing;
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

                // Download the QR as a PNG to the phone gallery.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _download,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: Text(_saving ? l10n.saving : l10n.downloadQr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
