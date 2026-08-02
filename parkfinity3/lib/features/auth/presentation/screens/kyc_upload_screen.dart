import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/auth_repository.dart';
import '../auth_controller.dart';
import '../../../shared/data/document_verification_service.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Mandatory identity verification shown once, right after role selection.
/// The router forces every user here until profiles.kyc_status = 'verified'.
///
/// Rider: NID front + NID back + driving license.
/// Owner: NID front + NID back + property document photo(s).
class KycUploadScreen extends ConsumerStatefulWidget {
  const KycUploadScreen({super.key});

  @override
  ConsumerState<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends ConsumerState<KycUploadScreen> {
  final _picker = ImagePicker();

  File? _nidFront;
  File? _nidBack;
  File? _license;
  final List<File> _propertyDocs = [];

  bool _busy = false; // running an ML Kit check on a just-picked image

  bool get _isOwner =>
      (ref.read(authRepositoryProvider).currentUser?.userMetadata?['role']
              as String?)
          ?.toLowerCase() ==
      'owner';

  Future<void> _pickAndVerify({
    required String slot, // 'nid_front' | 'nid_back' | 'license' | 'property'
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera, // force a live capture, not an old gallery pic
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final file = File(picked.path);

    setState(() => _busy = true);
    final svc = ref.read(documentVerificationProvider);
    DocVerifyResult result;
    switch (slot) {
      case 'nid_front':
      case 'nid_back':
        result = await svc.verifyNid(file);
        break;
      case 'license':
        result = await svc.verifyLicense(file);
        break;
      default:
        result = await svc.verifyPropertyDoc(file);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.valid) {
      _snack(result.reason, error: true);
      return;
    }

    setState(() {
      switch (slot) {
        case 'nid_front':
          _nidFront = file;
          break;
        case 'nid_back':
          _nidBack = file;
          break;
        case 'license':
          _license = file;
          break;
        default:
          _propertyDocs.add(file);
      }
    });
  }

  bool get _complete {
    if (_nidFront == null || _nidBack == null) return false;
    return _isOwner ? _propertyDocs.isNotEmpty : _license != null;
  }

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).submitKyc(
          nidFront: _nidFront!,
          nidBack: _nidBack!,
          licenseFile: _isOwner ? null : _license,
          propertyDocs: _isOwner ? _propertyDocs : const [],
        );
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (state.hasError) {
      _snack('${l10n.uploadFailed} ${state.error}', error: true);
    } else {
      _snack(l10n.verificationComplete);
      // Router redirect will now release the user to their home.
      final role = ref.read(authRepositoryProvider).currentUser
          ?.userMetadata?['role'] as String?;
      context.go(role?.toLowerCase() == 'owner'
          ? '/owner/dashboard'
          : '/rider/explore');
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(authControllerProvider).isLoading;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyIdentity),
        automaticallyImplyLeading: false,
      ),
      body: AbsorbPointer(
        absorbing: _busy || submitting,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _isOwner
                  ? l10n.kycOwnerIntro
                  : l10n.kycRiderIntro,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            _DocTile(
              label: l10n.nidFront,
              file: _nidFront,
              capturedText: l10n.captured,
              tapText: l10n.tapToCapture,
              onTap: () => _pickAndVerify(slot: 'nid_front'),
            ),
            _DocTile(
              label: l10n.nidBack,
              file: _nidBack,
              capturedText: l10n.captured,
              tapText: l10n.tapToCapture,
              onTap: () => _pickAndVerify(slot: 'nid_back'),
            ),
            if (!_isOwner)
              _DocTile(
                label: l10n.drivingLicense,
                file: _license,
                capturedText: l10n.captured,
                tapText: l10n.tapToCapture,
                onTap: () => _pickAndVerify(slot: 'license'),
              )
            else ...[
              for (var i = 0; i < _propertyDocs.length; i++)
                _DocTile(
                  label: '${l10n.propertyDocument} ${i + 1}',
                  file: _propertyDocs[i],
                  capturedText: l10n.captured,
                  tapText: l10n.tapToCapture,
                  onTap: () {},
                ),
              OutlinedButton.icon(
                onPressed: () => _pickAndVerify(slot: 'property'),
                icon: const Icon(Icons.add_a_photo),
                label: Text(_propertyDocs.isEmpty
                    ? l10n.addPropertyDoc
                    : l10n.addAnotherDoc),
              ),
            ],
            const SizedBox(height: 12),
            if (_busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(l10n.checkingDocument),
                ]),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_complete && !submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(l10n.submitContinue, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              child: Text(l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  final String capturedText;
  final String tapText;

  const _DocTile({
    required this.label,
    required this.file,
    required this.onTap,
    required this.capturedText,
    required this.tapText,
  });

  @override
  Widget build(BuildContext context) {
    final done = file != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: done
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(file!,
                    width: 48, height: 48, fit: BoxFit.cover),
              )
            : const Icon(Icons.upload_file, size: 32),
        title: Text(label),
        subtitle: Text(done ? capturedText : tapText),
        trailing: Icon(done ? Icons.check_circle : Icons.chevron_right,
            color: done ? Colors.green : null),
      ),
    );
  }
}
