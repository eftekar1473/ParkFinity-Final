import 'package:flutter/material.dart';

// Shows a user's KYC evidence (NID front/back, license, property docs) in a
// scrollable dialog. Pure presentation — takes a profile row map.
class KycDocsDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  const KycDocsDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, Map<String, dynamic> user) {
    return showDialog(context: context, builder: (_) => KycDocsDialog(user: user));
  }

  @override
  Widget build(BuildContext context) {
    final propertyDocs = (user['property_docs'] as List?) ?? const [];
    final docs = <MapEntry<String, String?>>[
      MapEntry('NID Front', user['nid_front_url'] as String?),
      MapEntry('NID Back', user['nid_back_url'] as String?),
      MapEntry('Driving License', user['license_url'] as String?),
      // legacy single-field fallbacks
      MapEntry('NID (legacy)', user['nid_url'] as String?),
      MapEntry('License (legacy)', user['driving_license_url'] as String?),
    ];
    for (var i = 0; i < propertyDocs.length; i++) {
      docs.add(MapEntry('Property Doc ${i + 1}', propertyDocs[i]?.toString()));
    }
    final present = docs.where((d) => (d.value ?? '').isNotEmpty).toList();

    return Dialog(
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.badge, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('KYC — ${user['full_name'] ?? user['email'] ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            Text('Status: ${user['kyc_status'] ?? 'none'}',
                style: Theme.of(context).textTheme.bodyMedium),
            const Divider(height: 24),
            Expanded(
              child: present.isEmpty
                  ? const Center(child: Text('No documents uploaded.'))
                  : ListView.separated(
                      itemCount: present.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _DocTile(label: present[i].key, url: present[i].value!),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String label;
  final String url;
  const _DocTile({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 220,
            fit: BoxFit.contain,
            loadingBuilder: (c, w, p) => p == null
                ? w
                : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
            errorBuilder: (c, e, s) => Container(
              height: 120,
              alignment: Alignment.center,
              color: Colors.grey.shade200,
              child: const Text('Could not load image'),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(url, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
