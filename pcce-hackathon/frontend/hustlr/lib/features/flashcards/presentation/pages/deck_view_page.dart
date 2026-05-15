import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/flashcards/data/ai_flashcard_service.dart';

class DeckViewPage extends StatefulWidget {
  final FlashcardDeck? deck;

  const DeckViewPage({super.key, this.deck});

  @override
  State<DeckViewPage> createState() => _DeckViewPageState();
}

class _DeckViewPageState extends State<DeckViewPage> {
  bool _flipped = false;
  int _current = 0;
  int _attempted = 0;
  int _strongRecall = 0;
  int _totalPoints = 0;
  late final List<FlashcardCard> _cards;
  late final List<Sm2CardState> _schedules;

  FlashcardDeck? get _deck => widget.deck;

  @override
  void initState() {
    super.initState();
    final fallbackDeck = FlashcardDeck(
      title: 'Flashcard Demo Deck',
      topic: 'Demo',
      sourceLabel: 'Local fallback',
      createdAt: DateTime.now(),
      cards: [
        FlashcardCard(
          question: 'What is a StatefulWidget in Flutter?',
          answer:
              'A widget that can hold mutable state and rebuild when setState is called.',
          type: FlashcardQuestionType.qa,
        ),
        FlashcardCard(
          question:
              'Fill in the blank: Flutter uses a reactive ____ pipeline for UI updates.',
          answer: 'rendering',
          type: FlashcardQuestionType.fillInBlank,
        ),
      ],
    );
    _cards = (_deck ?? fallbackDeck).cards;
    _schedules = List.generate(_cards.length, (_) => Sm2CardState.initial());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = _cards[_current];
    final title = _deck?.title ?? 'Flashcard Deck';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Text(
            '${_current + 1}/${_cards.length}',
            style: const TextStyle(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress
            LinearProgressIndicator(
              value: (_current + 1) / _cards.length,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            if (_deck != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Source: ${_deck!.sourceLabel}',
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Flashcard
            GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: _flipped
                      ? AppColors.tealGradient
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (_flipped ? AppColors.accent : AppColors.primary)
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _flipped ? 'Answer' : _typeLabel(card.type),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _flipped ? card.answer : card.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!_flipped) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Tap to reveal answer',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_flipped) ...[
              Text(
                'How well did you know this?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ratingBtn('Again', AppColors.error, isDark, 1, 0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ratingBtn('Hard', AppColors.warning, isDark, 3, 1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ratingBtn('Good', AppColors.primary, isDark, 4, 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ratingBtn('Easy', AppColors.success, isDark, 5, 3),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navBtn(LucideIcons.chevronLeft, () {
                    if (_current > 0) {
                      setState(() {
                        _current--;
                        _flipped = false;
                      });
                    }
                  }),
                  _navBtn(LucideIcons.chevronRight, () {
                    if (_current < _cards.length - 1) {
                      setState(() {
                        _current++;
                        _flipped = false;
                      });
                    }
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratingBtn(
    String label,
    Color color,
    bool isDark,
    int quality,
    int points,
  ) {
    return GestureDetector(
      onTap: () async {
        _attempted++;
        _totalPoints += points;
        if (quality >= 4) _strongRecall++;

        _schedules[_current] = AiFlashcardService.updateSm2Schedule(
          current: _schedules[_current],
          quality: quality,
        );

        if (_current < _cards.length - 1) {
          setState(() {
            _current++;
            _flipped = false;
          });
          return;
        }

        final result = _buildSessionResult();
        await _showCompletionSheet(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  String _typeLabel(FlashcardQuestionType type) {
    switch (type) {
      case FlashcardQuestionType.qa:
        return 'Q&A';
      case FlashcardQuestionType.fillInBlank:
        return 'Fill in the blank';
      case FlashcardQuestionType.trueFalse:
        return 'True / False';
      case FlashcardQuestionType.codeOutput:
        return 'Code output';
    }
  }

  FlashcardSessionResult _buildSessionResult() {
    final dueDates = _schedules.map((s) => s.dueDate).toList()
      ..sort((a, b) => a.compareTo(b));
    final nextReview = dueDates.isEmpty ? DateTime.now() : dueDates.first;
    final accuracy = _attempted == 0 ? 0.0 : (_strongRecall / _attempted) * 100;

    return FlashcardSessionResult(
      totalCards: _cards.length,
      attemptedCards: _attempted,
      strongRecall: _strongRecall,
      totalPoints: _totalPoints,
      accuracyPercent: accuracy,
      nextReviewDate: nextReview,
    );
  }

  Future<void> _showCompletionSheet(FlashcardSessionResult result) async {
    final deck = _deck;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Session Complete',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'Accuracy: ${result.accuracyPercent.toStringAsFixed(0)}%  |  Points: ${result.totalPoints}',
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Next review: ${result.nextReviewDate.day}/${result.nextReviewDate.month}/${result.nextReviewDate.year}',
                style: const TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: deck == null
                          ? null
                          : () async {
                              final text = AiFlashcardService.buildShareText(
                                deck,
                                result,
                              );
                              await Clipboard.setData(
                                ClipboardData(text: text),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Share text copied to clipboard',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(LucideIcons.share2, size: 16),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: deck == null
                          ? null
                          : () async {
                              final json = AiFlashcardService.exportDeckAsJson(
                                deck,
                              );
                              await Clipboard.setData(
                                ClipboardData(text: json),
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Deck JSON copied to clipboard',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(LucideIcons.download, size: 16),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, result);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to roadmap'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
