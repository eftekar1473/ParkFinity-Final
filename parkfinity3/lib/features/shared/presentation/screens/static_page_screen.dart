import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// One row of `static_pages` in the caller's language.
class StaticPage {
  final String slug;
  final String title;
  final String body;
  const StaticPage(
      {required this.slug, required this.title, required this.body});
}

final staticPageProvider =
    FutureProvider.family<StaticPage?, (String slug, String lang)>(
        (ref, key) async {
  final (slug, lang) = key;
  final rows = await Supabase.instance.client
      .from('static_pages')
      .select()
      .eq('slug', slug)
      .limit(1);
  if ((rows as List).isEmpty) return null;
  final r = Map<String, dynamic>.from(rows.first as Map);
  final bn = lang == 'bn';
  return StaticPage(
    slug: slug,
    title: (bn ? r['title_bn'] : r['title_en']) as String,
    body: (bn ? r['body_bn'] : r['body_en']) as String,
  );
});

/// Renders help / privacy / terms. The body uses `**bold**` line headings only,
/// so a full markdown dependency isn't warranted.
class StaticPageScreen extends ConsumerWidget {
  final String slug;
  const StaticPageScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pageAsync = ref.watch(staticPageProvider((slug, lang)));

    return Scaffold(
      appBar: AppBar(title: Text(pageAsync.value?.title ?? '')),
      body: pageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (page) {
          if (page == null) return Center(child: Text(l10n.noResults));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final line in page.body.split('\n'))
                _Line(line: line),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String line;
  const _Line({required this.line});

  @override
  Widget build(BuildContext context) {
    final t = line.trim();
    if (t.isEmpty) return const SizedBox(height: 12);

    if (t.startsWith('**') && t.endsWith('**')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          t.substring(2, t.length - 2),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
