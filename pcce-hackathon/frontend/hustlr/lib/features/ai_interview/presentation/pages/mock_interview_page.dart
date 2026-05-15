import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';

class MockInterviewPage extends StatelessWidget {
  const MockInterviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white70),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(LucideIcons.circle, color: AppColors.error, size: 8),
                  SizedBox(width: 6),
                  Text('REC · 12:34', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                child: const Text('Q 3/10', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 32),
            // AI Avatar
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)],
              ),
              child: const Center(child: Icon(LucideIcons.bot, color: Colors.white, size: 48)),
            ),
            const SizedBox(height: 12),
            const Text('SkillMap AI', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 32),
            // Question bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
              child: const Text(
                '"Can you explain the difference between StatelessWidget and StatefulWidget, and when you\'d choose one over the other?"',
                style: TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
              ),
            ),
            const Spacer(),
            // Answer input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Expanded(
                  child: Text('Tap mic to start answering...', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _controlBtn(LucideIcons.skipBack, Colors.white60, 44),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 18, spreadRadius: 2)],
                  ),
                  child: const Icon(LucideIcons.mic, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 20),
              _controlBtn(LucideIcons.skipForward, Colors.white60, 44),
            ]),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  Widget _controlBtn(IconData icon, Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
