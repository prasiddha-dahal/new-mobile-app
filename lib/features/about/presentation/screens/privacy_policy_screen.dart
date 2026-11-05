import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import 'legal_scaffold.dart';

/// What Sahayatri collects and who can see it.
///
/// Health data gets its own section rather than being folded into "information
/// we collect": a patient's reason for reading this page is almost always to
/// find out who can see their medical notes.
///
/// **The Nepali on this page has not been through legal review.** It was
/// written in the localisation sweep alongside the rest of the app, and a
/// policy is a statement a company is held to rather than copy. Whoever owns
/// the English text should read the Nepali before it ships — see
/// docs/localization.md.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LegalPage(
      title: l10n.privacyTitle,
      lastUpdated: l10n.legalUpdatedAugust2026,
      lede: l10n.privacyIntro,
      sections: [
        LegalSection(
          title: l10n.privacyCollectTitle,
          body: l10n.privacyCollectBody,
        ),
        LegalSection(title: l10n.privacyUseTitle, body: l10n.privacyUseBody),
        LegalSection(
          title: l10n.privacyHealthTitle,
          body: l10n.privacyHealthBody,
        ),
        LegalSection(
          title: l10n.privacySharingTitle,
          body: l10n.privacySharingBody,
        ),
        LegalSection(
          title: l10n.privacyRightsTitle,
          body: l10n.privacyRightsBody,
        ),
      ],
    );
  }
}
