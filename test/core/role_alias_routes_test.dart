import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/router/app_router.dart';
import 'package:sahayatri_care_connect/features/auth/domain/entities/user.dart';
import 'package:sahayatri_care_connect/features/auth/presentation/providers/auth_provider.dart';

/// Notifications, help, contact and the legal pages are reachable from both
/// roles, but a shell branch belongs to exactly one role's bottom bar — and
/// the auth redirect bounces a therapist off `/patient/*`. So each shell
/// carries its own copy under a role prefix and the bare paths are aliases.
///
/// Before this, `/notifications` was declared in both shells and go_router
/// matched the first, so a therapist opening notifications landed in the
/// patient shell. These pin the alias down for both roles.
void main() {
  User userWithRole(String role) => User(
    id: 'u1',
    name: 'Test',
    email: 'test@example.com',
    role: role,
    status: 'APPROVED',
  );

  /// Builds the real router with [role] signed in and asks it where [path]
  /// resolves to, without building any screens.
  Future<String> resolve(String role, String path) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Read the router first: it creates the AuthStateNotifier, which only
    // learns about a user by listening for the change below.
    final router = container.read(routerProvider);
    container.read(authProvider.notifier).state = userWithRole(role);

    final match = router.configuration.findMatch(Uri.parse(path));
    final redirected = await router.configuration.redirect(
      _FakeContext(),
      match,
      redirectHistory: <RouteMatchList>[],
    );
    return redirected.uri.path;
  }

  test('notifications resolves to the signed-in role own tab', () async {
    expect(
      await resolve('PATIENT', '/notifications'),
      '/patient/notifications',
    );
    expect(
      await resolve('THERAPIST', '/notifications'),
      '/therapist/notifications',
    );
  });

  test('support and legal pages resolve per role', () async {
    for (final path in ['/help', '/contact', '/about', '/about/terms']) {
      expect(await resolve('PATIENT', path), '/patient$path');
      expect(
        await resolve('THERAPIST', path),
        '/therapist$path',
        reason: '$path should stay inside the therapist shell',
      );
    }
  });

  test('a therapist is still kept out of the patient shell', () async {
    expect(await resolve('THERAPIST', '/patient/account'), '/therapist/home');
  });

  test('and a patient out of the therapist shell', () async {
    expect(await resolve('PATIENT', '/therapist/account'), '/patient/home');
  });
}

/// `redirect` only passes the context through to the route callbacks, and none
/// of the app's redirects touch it.
class _FakeContext extends Fake implements BuildContext {}
