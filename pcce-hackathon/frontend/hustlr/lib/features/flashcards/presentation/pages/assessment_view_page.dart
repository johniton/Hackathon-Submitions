import 'package:flutter/material.dart';
import 'package:hustlr/core/theme/app_colors.dart';
import 'package:hustlr/features/flashcards/data/ai_flashcard_service.dart';

class AssessmentViewPage extends StatefulWidget {
  final AssessmentDeck deck;

  const AssessmentViewPage({super.key, required this.deck});

  @override
  State<AssessmentViewPage> createState() => _AssessmentViewPageState();
}

class _AssessmentViewPageState extends State<AssessmentViewPage> {
  int _current = 0;
  int _correct = 0;
  late final List<AssessmentQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = widget.deck.questions;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _questions[_current];
    final total = _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(child: Text('${_current + 1}/$total')),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_current + 1) / total,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Topic: ${q.topic}',
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Text(
                    q.question,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Column(
                    children: List.generate(q.options.length, (i) {
                      final opt = q.options[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                          onPressed: () => _onSelect(i),
                          child: Align(alignment: Alignment.centerLeft, child: Text(opt)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSelect(int selected) async {
    final q = _questions[_current];
    final correct = selected == q.correctIndex;
    if (correct) _correct++;

    // brief feedback
    final color = correct ? AppColors.success : AppColors.error;
    final snack = SnackBar(
      content: Text(correct ? 'Correct' : 'Incorrect'),
      backgroundColor: color.withValues(alpha: 0.12),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);

    // next question or finish
    await Future.delayed(const Duration(milliseconds: 600));
    if (_current < _questions.length - 1) {
      setState(() => _current++);
      return;
    }

    // build result
    final attempted = _questions.length;
    final accuracy = (attempted == 0) ? 0.0 : (_correct / attempted) * 100.0;
    final result = FlashcardSessionResult(
      totalCards: attempted,
      attemptedCards: attempted,
      strongRecall: _correct,
      totalPoints: _correct,
      accuracyPercent: accuracy,
      nextReviewDate: DateTime.now().add(const Duration(days: 7)),
    );

    // show completion and return
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Assessment Complete'),
          content: Text('Score: ${accuracy.toStringAsFixed(0)}% ($_correct / $attempted)'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}
