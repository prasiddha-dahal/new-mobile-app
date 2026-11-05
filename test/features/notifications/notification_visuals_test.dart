import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_colors.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';
import 'package:sahayatri_care_connect/features/notifications/presentation/widgets/notification_visuals.dart';

/// The feed against its contract: `docs/notification_types.md` on the API
/// branch `feat/notification-events`. The 22 keys there are an API surface —
/// the client switches on them — so the thing worth pinning is that every one
/// renders, that a 23rd still renders, and that no tap goes anywhere the
/// router cannot take that role.
void main() {
  group('every type in the registry renders', () {
    test('all 22 have a glyph, a tint and a pill of their own', () {
      expect(notificationTypes, hasLength(22));

      for (final type in notificationTypes) {
        final visual = notificationVisualFor(type);
        expect(
          visual.glyph,
          isNot(unknownNotificationGlyph),
          reason: '$type fell through to the unknown-type fallback',
        );
        expect(visual.glyph, isNotEmpty, reason: type);
        expect(visual.tint, isNot(AppColors.inkMute), reason: type);
      }
    });

    test('the registry has no duplicates', () {
      expect(notificationTypes.toSet(), hasLength(notificationTypes.length));
    });

    test('a type the API added after this build shipped still renders', () {
      // The contract says adding a key is additive, so an app already on a
      // phone has to cope. It must not throw, and it must not render an empty
      // cell — the title and body are perfectly readable either way.
      for (final unknown in [
        'SESSION_REMINDER',
        'MESSAGE_RECEIVED',
        'POINTS_EXPIRING',
        'SOMETHING_INVENTED_IN_2027',
        '',
        'session_booked', // the contract says uppercase; lowercase is not it
      ]) {
        final visual = notificationVisualFor(unknown);
        expect(visual.glyph, unknownNotificationGlyph, reason: unknown);
        expect(visual.pill, NotificationPill.info, reason: unknown);
        expect(visual.tint, AppColors.inkMute, reason: unknown);
      }
    });

    test('the two design items with no producer are not faked', () {
      // The mock shows a "Session reminder" (needs a scheduler the API does
      // not have) and a "New message" (there is no messaging feature at all).
      // Neither is in the registry, and neither may have a bespoke icon here:
      // an icon is a promise that the row exists.
      expect(notificationTypes, isNot(contains('SESSION_REMINDER')));
      expect(notificationTypes, isNot(contains('MESSAGE_RECEIVED')));
      expect(
        notificationVisualFor('SESSION_REMINDER').glyph,
        unknownNotificationGlyph,
      );
    });
  });

  group('the pill rule', () {
    /// The rule, restated: `NEW` is "your turn", `DONE` is "settled",
    /// `INFO` is neither. These three lists are the whole registry, so a new
    /// type cannot be added without someone deciding which it is.
    const actionNeeded = {
      'SESSION_NEW_BOOKING',
      'SESSION_RESCHEDULE_REQUESTED',
      'SESSION_RATE_REQUEST',
      'REPORT_UPLOADED',
    };
    const info = {
      'SESSION_RESCHEDULED',
      'SESSION_DECLINE_REQUESTED',
      'REFUND_REQUESTED',
      'REFERRAL_JOINED',
    };

    test('classifies all 22 and nothing is left over', () {
      final done = notificationTypes
          .where((t) => !actionNeeded.contains(t) && !info.contains(t))
          .toSet();
      expect(actionNeeded.length + info.length + done.length, 22);

      for (final type in notificationTypes) {
        final expected = actionNeeded.contains(type)
            ? NotificationPill.actionNeeded
            : info.contains(type)
            ? NotificationPill.info
            : NotificationPill.done;
        expect(notificationVisualFor(type).pill, expected, reason: type);
      }
    });

    test('a decision that went badly is still settled, not still open', () {
      // DONE says "this is over", not "this went well". The tint carries the
      // valence; if rejections read NEW the pill would mean two things.
      for (final rejection in [
        'APPLICATION_REJECTED',
        'RATE_CHANGE_REJECTED',
        'LEAVE_REJECTED',
        'REFUND_DENIED',
        'SESSION_CANCELLED',
      ]) {
        expect(
          notificationVisualFor(rejection).pill,
          NotificationPill.done,
          reason: rejection,
        );
        expect(
          notificationVisualFor(rejection).tint,
          AppColors.danger,
          reason: '$rejection should look like bad news even though it is done',
        );
      }
    });

    test('every pill has a short uppercase label', () {
      for (final pill in NotificationPill.values) {
        expect(pill.label, pill.label.toUpperCase());
        expect(pill.label.length, lessThanOrEqualTo(4));
      }
    });

    test('a pill never wears the colour of the row it sits on', () {
      // `DONE`'s fill *is* the unread row's fill, so on an unread card the
      // badge was four pine letters with no badge around them — the same
      // component rendering two different ways one row apart. Caught by
      // rendering the screen; pinned here so it stays caught.
      for (final rowFill in [AppColors.pinePale, AppColors.card]) {
        for (final pill in NotificationPill.values) {
          expect(
            pill.backgroundOn(rowFill),
            isNot(rowFill),
            reason: '${pill.label} on $rowFill',
          );
        }
      }
      expect(
        NotificationPill.done.backgroundOn(AppColors.pinePale),
        AppColors.card,
      );
      expect(
        NotificationPill.done.backgroundOn(AppColors.card),
        AppColors.pinePale,
      );
    });
  });

  group('deep links', () {
    /// Every `refType` the contract defines, so a new one cannot quietly
    /// arrive with no decision made about it.
    const refTypes = [
      'SESSION',
      'PAYMENT',
      'REFUND',
      'REPORT',
      'THERAPIST',
      'RATE_CHANGE',
      'LEAVE',
      'REFERRAL',
      'POINTS',
    ];

    test('a session never sends a therapist into the patient shell', () {
      // The bug this replaces: `SESSION` went to /patient/sessions for
      // everyone, and the router's redirect bounced the therapist who tapped
      // it to /therapist/home — a different screen from the one they asked
      // for, with no explanation.
      expect(
        notificationDestinationFor(
          refType: 'SESSION',
          isTherapist: false,
        )?.path,
        '/patient/sessions',
      );
      expect(
        notificationDestinationFor(refType: 'SESSION', isTherapist: true)?.path,
        '/therapist/requests',
      );
    });

    test('no destination is ever the other role\'s', () {
      for (final refType in refTypes) {
        final asPatient = notificationDestinationFor(
          refType: refType,
          isTherapist: false,
        );
        final asTherapist = notificationDestinationFor(
          refType: refType,
          isTherapist: true,
        );
        expect(
          asPatient?.path,
          isNot(startsWith('/therapist')),
          reason: refType,
        );
        expect(
          asTherapist?.path,
          isNot(startsWith('/patient')),
          reason: refType,
        );
      }
    });

    test('a rate decision opens the therapist rate screen', () {
      // This used to be null, and the reason recorded on the table was that
      // `RateIncreaseScreen` was registered in no router — there was no path
      // to send anyone to. It is routed now, so the row goes where it was
      // always meant to: the screen whose `CURRENT` figure is the rate the
      // notification is about, read live from the therapist's own profile.
      expect(
        notificationDestinationFor(
          refType: 'RATE_CHANGE',
          isTherapist: true,
        )?.path,
        '/therapist/rate-increase',
      );
      // A sub-page, so it is pushed into whichever tab the feed was read in.
      expect(
        notificationDestinationFor(
          refType: 'RATE_CHANGE',
          isTherapist: true,
        )?.isTab,
        isFalse,
      );
      // A patient is never sent a rate row and has no such screen.
      expect(
        notificationDestinationFor(refType: 'RATE_CHANGE', isTherapist: false),
        isNull,
      );
    });

    test('refTypes with nowhere to go say so rather than guessing', () {
      // Null is the answer, and the tap still marks read. Sending a payment
      // receipt to the saved-cards screen would cost the reader their place
      // and still not answer the question the row raised.
      for (final refType in ['PAYMENT', 'REFUND']) {
        expect(
          notificationDestinationFor(refType: refType, isTherapist: false),
          isNull,
          reason: refType,
        );
        expect(
          notificationDestinationFor(refType: refType, isTherapist: true),
          isNull,
          reason: refType,
        );
      }
      expect(
        notificationDestinationFor(refType: null, isTherapist: false),
        isNull,
      );
      expect(
        notificationDestinationFor(refType: 'INVENTED', isTherapist: true),
        isNull,
      );
    });

    test('only tab roots are marked as tabs', () {
      // isTab decides go vs push. Pushing a tab root stacks a second copy of
      // it inside the Notifications tab; `go`ing to a sub-page yanks the user
      // out of the tab they were in.
      const tabRoots = {
        '/patient/home',
        '/patient/sessions',
        '/patient/recovery',
        '/patient/account',
        '/therapist/home',
        '/therapist/schedule',
        '/therapist/requests',
        '/therapist/account',
      };

      for (final refType in refTypes) {
        for (final isTherapist in [true, false]) {
          final destination = notificationDestinationFor(
            refType: refType,
            isTherapist: isTherapist,
          );
          if (destination == null) continue;
          expect(
            destination.isTab,
            tabRoots.contains(destination.path),
            reason: '${destination.path} ($refType)',
          );
        }
      }
    });

    group('against the real router', () {
      /// Asks the app's own router where [path] lands for a signed-in user of
      /// [role]. A path with no route resolves to the error page, so this
      /// catches a destination that does not exist as well as one the
      /// redirect bounces.
      Future<String> resolve(String path, String role) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final router = container.read(routerProvider);
        container.read(authProvider.notifier).state = User(
          id: 'u1',
          name: 'Test',
          email: 'test@example.com',
          role: role,
          status: 'APPROVED',
        );

        final match = router.configuration.findMatch(Uri.parse(path));
        final redirected = await router.configuration.redirect(
          _FakeContext(),
          match,
          redirectHistory: <RouteMatchList>[],
        );
        return redirected.uri.path;
      }

      test(
        'every destination resolves to itself for the role it is for',
        () async {
          for (final refType in refTypes) {
            for (final isTherapist in [true, false]) {
              final destination = notificationDestinationFor(
                refType: refType,
                isTherapist: isTherapist,
              );
              if (destination == null) continue;
              final role = isTherapist ? 'THERAPIST' : 'PATIENT';
              expect(
                await resolve(destination.path, role),
                destination.path,
                reason: '$refType as $role went somewhere else',
              );
            }
          }
        },
      );

      test(
        'and the destination the old code used does not, for a therapist',
        () async {
          // Kept as the reason the guard exists: this is what a therapist
          // tapping any session notification used to get.
          expect(
            await resolve('/patient/sessions', 'THERAPIST'),
            '/therapist/home',
          );
        },
      );
    });
  });
}

/// `redirect` only passes the context through to the route callbacks, and
/// none of the app's redirects touch it.
class _FakeContext extends Fake implements BuildContext {}
