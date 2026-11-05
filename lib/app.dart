import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/l10n.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme_data.dart';

class SahayatriApp extends ConsumerWidget {
  const SahayatriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Physioghar',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Includes the Material/Cupertino/Widgets delegates as well as ours, so
      // framework-supplied text (date pickers, dialog buttons) follows the
      // same choice the user made in the header.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(localeProvider),
    );
  }
}
