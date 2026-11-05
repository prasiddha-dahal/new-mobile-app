import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads .env if it is bundled. A missing or malformed file is not fatal —
  // AppConfig falls back to the local defaults — so the app still starts for
  // someone who has not copied .env.example yet.
  await AppConfig.load();

  runApp(
    const ProviderScope(
      child: SahayatriApp(),
    ),
  );
}
