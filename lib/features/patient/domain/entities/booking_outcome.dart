import 'session.dart';

/// What the gateway wants the client to do next.
///
/// The server decides this, not the app: eSewa needs a signed form POST whose
/// signature covers the amount, so the fields cannot be rebuilt here, and
/// Khalti hands back a one-time hosted-checkout URL.
enum CheckoutKind {
  /// Open [GatewayCheckout.url].
  redirect('redirect'),

  /// POST [GatewayCheckout.formFields] to [GatewayCheckout.url].
  form('form'),

  /// Nothing to pay online.
  manual('manual'),

  unknown('');

  const CheckoutKind(this.wireValue);
  final String wireValue;

  static CheckoutKind fromWire(String? value) =>
      CheckoutKind.values.firstWhere(
        (k) => k.wireValue == (value ?? '').toLowerCase(),
        orElse: () => CheckoutKind.unknown,
      );
}

/// A checkout the patient still has to complete.
class GatewayCheckout {
  const GatewayCheckout({
    required this.paymentId,
    required this.kind,
    this.url,
    this.formFields = const {},
    this.expiresAt,
  });

  /// The payment to confirm once the gateway sends the patient back.
  final String paymentId;

  final CheckoutKind kind;
  final String? url;
  final Map<String, String> formFields;
  final DateTime? expiresAt;

  /// False when the server said "gateway" but gave us nothing to open — a
  /// misconfiguration we must surface rather than sit on a blank page for.
  bool get isUsable =>
      (kind == CheckoutKind.redirect || kind == CheckoutKind.form) &&
      (url ?? '').isNotEmpty;
}

/// The result of `POST /payments/process`.
///
/// The booking call returns three things and the app used to keep one. A cash
/// booking really is done when this comes back; a gateway booking is a
/// `PENDING_HOLD` with its slot still unlocked and a checkout the patient has
/// not visited yet. Collapsing both to a `Session` is what let the app show a
/// confirmation screen for a booking the server would cancel twenty minutes
/// later.
class BookingOutcome {
  const BookingOutcome({
    required this.session,
    required this.paymentId,
    required this.paymentStatus,
    this.checkout,
  });

  final Session session;
  final String paymentId;
  final String paymentStatus;

  /// Null for cash and for any method settled at booking time.
  final GatewayCheckout? checkout;

  /// Whether the patient still owes the gateway a visit.
  bool get needsCheckout => checkout != null;

  /// True when the booking is real and final as it stands.
  bool get isConfirmed => !needsCheckout && !session.status.isAwaitingPayment;
}
