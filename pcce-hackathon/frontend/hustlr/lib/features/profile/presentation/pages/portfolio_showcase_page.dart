import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';

class PortfolioShowcasePage extends StatelessWidget {
  const PortfolioShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(height: 30),
                  const CircleAvatar(radius: 40, backgroundColor: Colors.white24, child: Text('U', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
                  const SizedBox(height: 12),
                  const Text('Your Portfolio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                  const Text('Frontend Developer', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(LucideIcons.github, size: 14, color: Colors.white), SizedBox(width: 6), Text('GitHub', style: TextStyle(color: Colors.white, fontSize: 11))])),
                    const SizedBox(width: 10),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(LucideIcons.globe, size: 14, color: Colors.white), SizedBox(width: 6), Text('Website', style: TextStyle(color: Colors.white, fontSize: 11))])),
                  ]),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('Featured Projects', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _projectCard('Hustlr App', 'Flutter, Firebase, Riverpod', 'A career readiness platform with AI mock interviews and skill swapping.', 'https://github.com/alex/hustlr', 120, isDark),
                const SizedBox(height: 16),
                _projectCard('Weather Dashboard', 'React, Next.js, Tailwind', 'Real-time weather tracking with beautiful dynamic gradients.', 'https://github.com/alex/weather', 45, isDark),
                const SizedBox(height: 16),
                _projectCard('Crypto Tracker', 'Swift, iOS, CoreData', 'Native iOS app to track crypto portfolios and live price updates.', 'https://github.com/alex/crypto', 89, isDark),
                const SizedBox(height: 30),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add Project'),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(String title, String stack, String desc, String link, int stars, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.folderGit2, color: AppColors.primary, size: 18)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          Row(children: [
            const Icon(LucideIcons.star, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('$stars', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 12),
        Text(desc, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(stack, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          const Icon(LucideIcons.externalLink, size: 14, color: AppColors.textSecondaryLight),
        ]),
      ]),
    );
  }
}
