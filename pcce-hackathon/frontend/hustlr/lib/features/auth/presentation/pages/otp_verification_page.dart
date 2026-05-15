import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/primary_button.dart';
import 'package:hustlr/main.dart';

class OtpVerificationPage extends StatelessWidget {
  const OtpVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.arrowLeft), alignment: Alignment.centerLeft),
            const SizedBox(height: 32),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(LucideIcons.smartphone, size: 48, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text('Verify your number', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text('Enter the 6-digit OTP sent to +91 98765 43210', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 40),
            // OTP boxes
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _otpBox(context, i == 0))),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Verify OTP',
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainAppShell())),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Didn't receive OTP? ", style: TextStyle(color: AppColors.textSecondaryLight)),
              GestureDetector(
                onTap: () {},
                child: const Text('Resend', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _otpBox(BuildContext context, bool active) {
    return Container(
      width: 48, height: 56,
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.06) : (Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12), width: active ? 2 : 1),
      ),
      child: Center(
        child: active ? Container(width: 2, height: 22, color: AppColors.primary) : null,
      ),
    );
  }
}
