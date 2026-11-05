import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import 'legal_scaffold.dart';

/// The terms a patient accepts at signup.
///
/// The liability section states plainly that Sahayatri is a marketplace and
/// care is delivered by independent professionals — the same framing the
/// signup screen's "I agree to the Terms" checkbox points at.
///
/// **The Nepali on this page has not been through legal review.** These are
/// the terms a user is held to, and the refund windows and the liability
/// disclaimer in particular say something specific. Whoever owns the English
/// text should read the Nepali before it ships — see docs/localization.md.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LegalPage(
      title: l10n.termsTitle,
      lastUpdated: l10n.legalUpdatedAugust2026,
      lede: l10n.termsIntro,
      sections: [
        LegalSection(
          title: l10n.termsServiceTitle,
          body: l10n.termsServiceBody,
        ),
        LegalSection(
          title: l10n.termsBookingTitle,
          body: l10n.termsBookingBody,
        ),
        LegalSection(
          title: l10n.termsPaymentsTitle,
          body: l10n.termsPaymentsBody,
        ),
        LegalSection(
          title: l10n.termsConductTitle,
          body: l10n.termsConductBody,
        ),
        LegalSection(
          title: l10n.termsLiabilityTitle,
          body: l10n.termsLiabilityBody,
        ),
      ],
    );
  }
}
