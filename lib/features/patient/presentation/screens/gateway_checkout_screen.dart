import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/theme/app_typography.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../domain/entities/booking_outcome.dart';
import '../providers/patient_providers.dart';

/// Where a gateway booking actually gets paid for.
///
/// Booking with eSewa or Khalti creates the session as `PENDING_HOLD` and
/// deliberately leaves the slot unlocked — the hold is not a booking, and the
/// server sweeps an abandoned one to CANCELLED after twenty minutes. Until
/// this screen existed the app went straight from that response to the
/// booking-confirmed screen, so a patient who chose a wallet was shown a
/// confirmation for an appointment nobody was coming to.
///
/// The gateways redirect back to a URL configured server-side (the web
/// frontend's webhook route), which the app cannot swap for a deep link of
/// its own. So checkout runs in a WebView and this screen watches navigation
/// for that URL: reaching it means the gateway is done, and whatever it hung
/// on the query string is what `POST /payments/{id}/confirm` needs. eSewa puts
/// a signed blob in `data`; Khalti sends `pidx` and friends.
///
/// Nothing here decides whether the payment succeeded. The gateway's word
/// arrives on a URL the patient's own browser was just on, so it is only a
/// signal to go and ask the server, which verifies against the gateway
/// directly.
class GatewayCheckoutScreen extends ConsumerStatefulWidget {
  const GatewayCheckoutScreen({super.key, required this.outcome});

  final BookingOutcome outcome;

  @override
  ConsumerState<GatewayCheckoutScreen> createState() =>
      _GatewayCheckoutScreenState();
}

enum _Phase { loading, checkout, verifying, done }

class _GatewayCheckoutScreenState extends ConsumerState<GatewayCheckoutScreen> {
  late final WebViewController _controller;

  _Phase _phase = _Phase.loading;
  String? _error;

  /// Guards against confirming twice: a gateway can bounce through its return
  /// URL more than once (a redirect chain, or a reload), and each pass would
  /// otherwise fire another confirm.
  bool _confirming = false;

  GatewayCheckout get _checkout => widget.outcome.checkout!;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted && _phase == _Phase.loading) {
              setState(() => _phase = _Phase.checkout);
            }
          },
          onNavigationRequest: (request) {
            if (_isReturnUrl(request.url)) {
              _confirm(Uri.parse(request.url).queryParameters);
              // Stop rather than let the WebView load the web frontend's
              // webhook route, which would render a page meant for a browser
              // session this app does not have.
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (err) {
            // Subframe errors are noise — an analytics pixel failing is not a
            // failed payment, and treating it as one would abandon a checkout
            // the patient is midway through.
            if (!err.isForMainFrame!) return;
            if (!mounted || _phase == _Phase.verifying) return;
            setState(() {
              _phase = _Phase.done;
              _error = context.l10n.checkoutCouldNotOpen;
            });
          },
        ),
      );
    _start();
  }

  /// The gateway is finished when it sends the patient to the configured
  /// return URL. Matched on path rather than on the whole URL because the
  /// host differs per environment and the query string is the payload.
  bool _isReturnUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    return path.contains('/webhooks/payments/');
  }

  void _start() {
    final url = _checkout.url;
    if (!_checkout.isUsable || url == null) {
      // The server said "gateway" and gave us nothing to open. Saying so beats
      // a blank page the patient waits on.
      setState(() {
        _phase = _Phase.done;
        _error = context.l10n.checkoutUnavailable;
      });
      return;
    }

    switch (_checkout.kind) {
      case CheckoutKind.redirect:
        _controller.loadRequest(Uri.parse(url));
      case CheckoutKind.form:
        // eSewa takes a signed form POST, and the signature covers the amount
        // and the transaction id — the fields cannot be rebuilt here, only
        // forwarded. `loadHtmlString` cannot POST, so the page does it.
        _controller.loadHtmlString(_autoSubmitForm(url, _checkout.formFields));
      case CheckoutKind.manual:
      case CheckoutKind.unknown:
        setState(() {
          _phase = _Phase.done;
          _error = context.l10n.checkoutUnavailable;
        });
    }
  }

  Future<void> _confirm(Map<String, String> params) async {
    if (_confirming) return;
    _confirming = true;
    if (!mounted) return;
    setState(() => _phase = _Phase.verifying);

    final result = await ref
        .read(patientActionsProvider)
        .confirmPayment(paymentId: _checkout.paymentId, params: params);

    if (!mounted) return;

    result.match(
      (failure) => setState(() {
        _phase = _Phase.done;
        _error = failure.message;
        // Another attempt is legitimate: confirm is idempotent server-side,
        // and the usual cause here is a dropped connection rather than a
        // refused payment.
        _confirming = false;
      }),
      (outcome) => _onConfirmed(outcome),
    );
  }

  void _onConfirmed(String result) {
    final l10n = context.l10n;
    switch (result.toUpperCase()) {
      case 'COMPLETED':
      case 'ALREADY_COMPLETED':
        context.pushReplacement(
          '/patient/booking-success',
          extra: widget.outcome.session,
        );
      case 'CONFLICT':
        // Paid, and somebody else took the slot while the hold was open. The
        // server has already cancelled the session and flagged a refund; the
        // one thing the patient must not be told is that they are booked.
        setState(() {
          _phase = _Phase.done;
          _error = l10n.checkoutSlotTaken;
        });
      case 'REFUND_REQUIRED':
        // Paid for a booking that had already expired or been cancelled.
        // The server kept the payment and flagged a refund; again, the
        // patient must not be told they are booked.
        setState(() {
          _phase = _Phase.done;
          _error = l10n.checkoutRefundRequired;
        });
      case 'PENDING':
        setState(() {
          _phase = _Phase.done;
          _error = l10n.checkoutStillPending;
          _confirming = false;
        });
      default:
        setState(() {
          _phase = _Phase.done;
          _error = l10n.checkoutNotCompleted;
          _confirming = false;
        });
    }
  }

  /// A page whose only job is to POST [fields] to [url] the moment it loads.
  static String _autoSubmitForm(String url, Map<String, String> fields) {
    final inputs = fields.entries
        .map(
          (e) =>
              '<input type="hidden" name="${_esc(e.key)}" '
              'value="${_esc(e.value)}">',
        )
        .join();
    return '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        '</head><body onload="document.forms[0].submit()">'
        '<form method="POST" action="${_esc(url)}">$inputs</form>'
        '</body></html>';
  }

  static String _esc(String v) => const HtmlEscape().convert(v);

  void _close() =>
      context.canPop() ? context.pop() : context.go('/patient/sessions');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      // Backing out mid-checkout leaves an unpaid hold behind, so it gets a
      // confirmation rather than happening on a stray gesture.
      canPop: _phase == _Phase.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAbandon();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: l10n.checkoutTitle,
                onBack: _phase == _Phase.done ? _close : _confirmAbandon,
              ),
              if (_phase == _Phase.checkout || _phase == _Phase.loading)
                _HoldBanner(expiresAt: _checkout.expiresAt),
              Expanded(child: _body(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_phase == _Phase.done) {
      return _CheckoutProblem(
        message: _error ?? l10n.checkoutNotCompleted,
        onRetry: _confirming ? null : () => _confirm(const {}),
        onClose: _close,
      );
    }

    if (_phase == _Phase.verifying) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.pine),
            const SizedBox(height: 16),
            Text(
              l10n.checkoutVerifying,
              style: const TextStyle(fontSize: 14, color: AppColors.inkMid),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                l10n.checkoutDoNotClose,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.inkMute),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_phase == _Phase.loading)
          const Center(child: CircularProgressIndicator(color: AppColors.pine)),
      ],
    );
  }

  Future<void> _confirmAbandon() async {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.checkoutLeaveTitle),
        content: Text(l10n.checkoutLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.checkoutLeaveStay,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.checkoutLeaveConfirm,
              style: text.bodyMedium!.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _close();
  }
}

/// Says out loud that the slot is not held indefinitely.
class _HoldBanner extends StatelessWidget {
  const _HoldBanner({this.expiresAt});

  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Text(
        context.l10n.checkoutHoldNote,
        style: const TextStyle(fontSize: 12, color: AppColors.inkMid),
      ),
    );
  }
}

class _CheckoutProblem extends StatelessWidget {
  const _CheckoutProblem({
    required this.message,
    required this.onClose,
    this.onRetry,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.inkMute),
            const SizedBox(height: 12),
            Text(
              l10n.checkoutNotCompleted,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.inkMid),
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRetry,
                  child: Text(l10n.checkoutCheckAgain),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onClose,
                child: Text(l10n.checkoutBackToSessions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
