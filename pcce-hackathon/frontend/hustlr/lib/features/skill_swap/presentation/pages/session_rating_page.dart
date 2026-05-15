import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/core/widgets/glass_card.dart';
import 'package:hustlr/features/skill_swap/domain/models/skill_swap_models.dart';
import 'package:hustlr/features/skill_swap/data/skill_swap_provider.dart';

class SessionRatingPage extends StatefulWidget {
  final SwapSession session;
  final SkillSwapProvider? prov;
  const SessionRatingPage({super.key, required this.session, this.prov});

  @override
  State<SessionRatingPage> createState() => _SessionRatingPageState();
}

class _SessionRatingPageState extends State<SessionRatingPage>
    with SingleTickerProviderStateMixin {
  double _rating = 0;
  final _feedbackCtrl = TextEditingController();
  bool _submitting = false;

  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Rate Session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Session summary ─────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(widget.session.peer.avatar,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.session.peer.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(widget.session.topicCovered,
                          style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('${widget.session.durationMinutes} min · Video',
                          style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 11)),
                    ]),
              ),
            ]),
          ),

          const SizedBox(height: 32),

          // ── Star rating ─────────────────────────────────────────────────
          Center(
            child: Column(children: [
              const Text('How was the session?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text('Rate ${widget.session.peer.name.split(' ').first}\'s session',
                  style: const TextStyle(
                      color: AppColors.textSecondaryLight, fontSize: 13)),
              const SizedBox(height: 24),

              // Star row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = i + 1.0);
                      _starController.forward(from: 0);
                    },
                    child: AnimatedScale(
                      scale: (i < _rating) ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          filled ? LucideIcons.star : LucideIcons.star,
                          size: 44,
                          color: filled ? AppColors.warning : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),
              if (_rating > 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _ratingLabel(_rating.toInt()),
                    key: ValueKey(_rating),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.warning),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 32),

          // ── Topics covered ──────────────────────────────────────────────
          Text('What was covered?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            'Great explanation',
            'Well-prepared',
            'Practical examples',
            'Friendly & patient',
            'Engaged learner',
            'On time',
          ].map((t) {
            return _TagChip(label: t);
          }).toList()),

          const SizedBox(height: 24),

          // ── Written feedback ────────────────────────────────────────────
          Text('Leave a note (optional)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: _feedbackCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What went well? Any suggestions for your peer?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Submit ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: (_rating == 0 || _submitting) ? null : _submit,
            child: AnimatedOpacity(
              opacity: _rating == 0 ? 0.5 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _rating > 0
                      ? [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ]
                      : null,
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Rating',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                ),
              ),
            ),
          ),

          if (_rating == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text('Select a star rating to continue',
                    style: TextStyle(
                        color: AppColors.textSecondaryLight, fontSize: 11)),
              ),
            ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  String _ratingLabel(int r) => switch (r) {
        1 => '😞 Needs improvement',
        2 => '😐 Could be better',
        3 => '🙂 It was OK',
        4 => '😊 Good session!',
        5 => '🌟 Outstanding!',
        _ => '',
      };

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    // Save to Supabase via provider if available
    if (widget.prov != null) {
      try {
        await widget.prov!.submitRating(
          sessionId: widget.session.id,
          rating: _rating,
          feedback: _feedbackCtrl.text.trim().isEmpty ? null : _feedbackCtrl.text.trim(),
        );
      } catch (_) {
        // Show rating locally even if save fails
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    _showThankYou();
  }

  void _showThankYou() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration:
                const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
            child: const Icon(LucideIcons.star, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Thank you! 🎉',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            '${_ratingLabel(_rating.toInt())}. Your feedback helps ${widget.session.peer.name.split(' ').first} grow.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondaryLight, fontSize: 13),
          ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back
              },
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tag chip ─────────────────────────────────────────────────────────────────

class _TagChip extends StatefulWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selected = !_selected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: _selected ? AppColors.primaryGradient : null,
          color: _selected ? null : AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _selected
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(widget.label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _selected ? Colors.white : AppColors.primary)),
      ),
    );
  }
}
