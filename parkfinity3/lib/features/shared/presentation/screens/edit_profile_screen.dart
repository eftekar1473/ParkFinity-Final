import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/my_profile_repository.dart';
import '../../../../l10n/generated/app_localizations.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();

  /// Locally picked avatar: shown immediately, uploaded on save.
  File? _pickedAvatar;
  bool _saving = false;
  bool _seeded = false;
  String? _error;

  static final _bdPhone = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _seed(UserProfile p) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = p.fullName;
    _phoneController.text = p.phoneNumber ?? '';
  }

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img != null) setState(() => _pickedAvatar = File(img.path));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = l10n.nameRequired);
      return;
    }
    if (phone.isNotEmpty &&
        !_bdPhone.hasMatch(phone.replaceAll(RegExp(r'[\s-]'), ''))) {
      setState(() => _error = l10n.invalidPhone);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(myProfileRepositoryProvider);
      String? avatarUrl;
      if (_pickedAvatar != null) {
        avatarUrl = await repo.uploadAvatar(_pickedAvatar!);
      }
      await repo.update(
        fullName: name,
        phone: phone.isEmpty ? null : phone,
        avatarUrl: avatarUrl,
      );
      ref.invalidate(currentProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.profileUpdated)));
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.somethingWentWrong));
          }
          _seed(profile);

          final ImageProvider? avatar = _pickedAvatar != null
              ? FileImage(_pickedAvatar!)
              : (profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(
                              profile.displayName.characters.first
                                  .toUpperCase(),
                              style: const TextStyle(fontSize: 36),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _saving ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(Icons.camera_alt,
                                size: 18,
                                color: theme.colorScheme.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : _pickAvatar,
                  child: Text(l10n.changePhoto),
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style:
                        TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.fullName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phoneNumber,
                  hintText: '01712345678',
                  helperText: l10n.phoneNumberHelper,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // Email is owned by the auth provider, so it is read-only here.
              TextField(
                enabled: false,
                controller: TextEditingController(text: profile.email),
                decoration: InputDecoration(
                  labelText: l10n.email,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.saveChanges),
              ),
            ],
          );
        },
      ),
    );
  }
}
