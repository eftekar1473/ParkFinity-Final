import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/qr_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Which side of the parking session this scan performs.
enum ScanMode { checkIn, checkOut }

/// Camera scanner for the QR poster mounted at the spot. Falls back to typing
/// the 6-character short code when the camera can't read the print.
class QrScanScreen extends ConsumerStatefulWidget {
  final ScanMode mode;
  const QrScanScreen({super.key, required this.mode});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _codeController = TextEditingController();

  /// Guards against the detector firing repeatedly while the RPC is in flight.
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit(String rawToken) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(qrRepositoryProvider);
      final res = widget.mode == ScanMode.checkIn
          ? await repo.checkIn(rawToken)
          : await repo.checkOut(rawToken);

      if (!mounted) return;
      if (!res.ok) {
        setState(() => _error = res.message);
        return;
      }
      Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _promptForCode() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shortCode),
        content: TextField(
          controller: _codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'A1B2C3',
            border: const OutlineInputBorder(),
            counterText: '',
            labelText: l10n.shortCode,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final code = _codeController.text.trim();
              Navigator.pop(ctx);
              if (code.length == 6) _submit(code);
            },
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCheckIn = widget.mode == ScanMode.checkIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCheckIn ? l10n.checkIn : l10n.checkOut),
        actions: [
          IconButton(
            tooltip: l10n.enterCodeManually,
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _busy ? null : _promptForCode,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(l10n.cameraPermissionNeeded,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _promptForCode,
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      label: Text(l10n.enterCodeManually),
                    ),
                  ],
                ),
              ),
            ),
            onDetect: (capture) {
              final value = capture.barcodes
                  .map((b) => b.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (value != null) _submit(value);
            },
          ),

          // Reticle
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLow, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCheckIn ? l10n.scanToStart : l10n.scanToEnd,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.surfaceContainerLow, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),

          if (_busy)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
