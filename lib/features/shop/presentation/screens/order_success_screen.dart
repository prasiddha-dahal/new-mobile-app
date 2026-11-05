import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.pinePale,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, size: 32, color: AppColors.pine),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.orderPlaced,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.orderDeliveryNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.inkMid),
              ),
              // No reference line. There is no order entity (A6 in
              // docs/TODO_REGISTER.md), so there is no reference to show, and
              // what stood here was the spec's *sample* — `SAH-EQ-90213`,
              // identical for every order ever placed. Quoting it to support
              // would mean nothing. `booking_success_screen.dart` does the
              // same thing next door and says so: it prints the real session
              // id when there is one and omits the line when there is not.
              // TODO(api): order create, then show its id here (A6).
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/patient/home'),
                  child: Text(context.l10n.actionBackToHome),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.go('/shop'),
                  child: Text(context.l10n.orderContinueShopping),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
