import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../data/my_profile_repository.dart';
import '../widgets/notification_bell.dart';
import '../../../../core/controllers/settings_controller.dart';
import '../../../../l10n/generated/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfile,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: const [NotificationBell()],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(currentProfileProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.somethingWentWrong));
          }
          final isOwner = profile.isOwner;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(currentProfileProvider),
            child: ListView(
              children: [
                _Header(profile: profile),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(l10n.accountSettings),
                      _Tile(
                        icon: Icons.person_outline,
                        title: l10n.editProfile,
                        onTap: () => context.push('/profile/edit'),
                      ),
                      if (!isOwner)
                        _Tile(
                          icon: Icons.directions_car_outlined,
                          title: l10n.myVehicles,
                          onTap: () => context.push('/rider/profile/vehicles'),
                        ),
                      _Tile(
                        icon: Icons.history,
                        title: l10n.bookingHistory,
                        onTap: () => context.push(
                            isOwner ? '/owner/bookings' : '/rider/bookings'),
                      ),
                      // KYC documents are collected once during sign-up, so this
                      // is a status readout, not another upload entry point.
                      _StatusTile(profile: profile),

                      const SizedBox(height: 24),
                      _SectionLabel(l10n.settings),
                      _Tile(
                        icon: Icons.language,
                        title: l10n.language,
                        trailing: Consumer(
                          builder: (context, ref, _) {
                            final locale = ref.watch(localeProvider);
                            return Text(
                              locale?.languageCode == 'bn' ? 'বাংলা' : 'English',
                              style: TextStyle(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                        onTap: () => ref.read(localeProvider.notifier).toggle(),
                      ),
                      _Tile(
                        icon: Icons.brightness_6_outlined,
                        title: l10n.theme,
                        trailing: Consumer(
                          builder: (context, ref, _) {
                            final mode = ref.watch(themeModeProvider);
                            final label = switch (mode) {
                              ThemeMode.dark => 'Dark',
                              ThemeMode.light => 'Light',
                              _ => 'System',
                            };
                            return Text(label,
                                style: TextStyle(
                                    color: theme.hintColor,
                                    fontWeight: FontWeight.w500));
                          },
                        ),
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).cycle(),
                      ),

                      const SizedBox(height: 24),
                      _SectionLabel(l10n.supportAbout),
                      _Tile(
                        icon: Icons.help_outline,
                        title: l10n.helpCenter,
                        onTap: () => context.push('/page/help'),
                      ),
                      _Tile(
                        icon: Icons.policy_outlined,
                        title: l10n.privacyPolicy,
                        onTap: () => context.push('/page/privacy'),
                      ),
                      _Tile(
                        icon: Icons.gavel_outlined,
                        title: l10n.termsOfService,
                        onTap: () => context.push('/page/terms'),
                      ),

                      const SizedBox(height: 24),
                      ListTile(
                        onTap: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.logout,
                              color: theme.colorScheme.error),
                        ),
                        title: Text(l10n.logOut,
                            style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = profile.avatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/edit'),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          profile.displayName.characters.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 36,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit,
                        color: theme.colorScheme.onPrimary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(profile.displayName,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(profile.email,
              style: TextStyle(color: theme.hintColor, fontSize: 16)),
          if (profile.phoneNumber != null) ...[
            const SizedBox(height: 2),
            Text(profile.phoneNumber!,
                style: TextStyle(color: theme.hintColor, fontSize: 15)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                icon: Icons.star,
                color: Colors.amber,
                // Riders with no reviews yet shouldn't see a fake 4.8.
                label: profile.reviewCount == 0
                    ? '—'
                    : '${profile.avgRating.toStringAsFixed(1)} (${profile.reviewCount})',
              ),
              _Chip(
                icon: profile.isOwner
                    ? Icons.storefront_outlined
                    : Icons.directions_car_outlined,
                color: theme.colorScheme.primary,
                label: profile.role,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Chip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final UserProfile profile;
  const _StatusTile({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (label, color, icon) = switch (profile.kycStatus) {
      'verified' => (l10n.verifiedStatus, Colors.green, Icons.verified_user),
      'pending' => (l10n.pendingStatus, Colors.orange, Icons.hourglass_top),
      _ => (l10n.notSubmittedStatus, theme.colorScheme.error, Icons.gpp_maybe),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(l10n.verificationStatus,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(l10n.documentsSubmittedNote,
            style: TextStyle(color: theme.hintColor, fontSize: 12)),
        trailing: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
