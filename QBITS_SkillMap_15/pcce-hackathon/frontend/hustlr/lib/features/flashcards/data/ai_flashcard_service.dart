import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

enum FlashcardSourceType {
  roadmapTopic,
  pastedNotes,
  youtubeTranscript,
  uploadedNotes,
}

enum FlashcardQuestionType { qa, fillInBlank, trueFalse, codeOutput }

class FlashcardCard {
  final String question;
  final String answer;
  final FlashcardQuestionType type;

  const FlashcardCard({
    required this.question,
    required this.answer,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'answer': answer,
    'type': type.name,
  };
}

class FlashcardDeck {
  final String title;
  final String topic;
  final String sourceLabel;
  final List<FlashcardCard> cards;
  final DateTime createdAt;

  const FlashcardDeck({
    required this.title,
    required this.topic,
    required this.sourceLabel,
    required this.cards,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'topic': topic,
    'sourceLabel': sourceLabel,
    'createdAt': createdAt.toIso8601String(),
    'cards': cards.map((c) => c.toJson()).toList(),
  };
}

class AssessmentQuestion {
  final String topic;
  final String question;
  final List<String> options;
  final int correctIndex;

  const AssessmentQuestion({
    required this.topic,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
      };
}

class AssessmentDeck {
  final String title;
  final String skillOrRole;
  final List<AssessmentQuestion> questions;
  final DateTime createdAt;

  const AssessmentDeck({
    required this.title,
    required this.skillOrRole,
    required this.questions,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'skillOrRole': skillOrRole,
        'createdAt': createdAt.toIso8601String(),
        'questions': questions.map((q) => q.toJson()).toList(),
      };
}

class PracticalProject {
  final String title;
  final String rolePlayContext;
  final String whyItMatters;
  final List<String> deliverables;
  final List<String> starterSteps;
  final List<String> skills;

  const PracticalProject({
    required this.title,
    required this.rolePlayContext,
    required this.whyItMatters,
    required this.deliverables,
    required this.starterSteps,
    required this.skills,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'rolePlayContext': rolePlayContext,
        'whyItMatters': whyItMatters,
        'deliverables': deliverables,
        'starterSteps': starterSteps,
        'skills': skills,
      };
}

class PracticalProjectPack {
  final String title;
  final String skillOrRole;
  final List<PracticalProject> projects;
  final DateTime createdAt;

  const PracticalProjectPack({
    required this.title,
    required this.skillOrRole,
    required this.projects,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'skillOrRole': skillOrRole,
        'createdAt': createdAt.toIso8601String(),
        'projects': projects.map((p) => p.toJson()).toList(),
      };
}

class Sm2CardState {
  final int repetitions;
  final int intervalDays;
  final double easeFactor;
  final DateTime dueDate;

  const Sm2CardState({
    required this.repetitions,
    required this.intervalDays,
    required this.easeFactor,
    required this.dueDate,
  });

  factory Sm2CardState.initial() {
    final now = DateTime.now();
    return Sm2CardState(
      repetitions: 0,
      intervalDays: 0,
      easeFactor: 2.5,
      dueDate: DateTime(now.year, now.month, now.day),
    );
  }
}

class FlashcardSessionResult {
  final int totalCards;
  final int attemptedCards;
  final int strongRecall;
  final int totalPoints;
  final double accuracyPercent;
  final DateTime nextReviewDate;

  const FlashcardSessionResult({
    required this.totalCards,
    required this.attemptedCards,
    required this.strongRecall,
    required this.totalPoints,
    required this.accuracyPercent,
    required this.nextReviewDate,
  });
}

class AiFlashcardService {
  // Gemini API key loaded from .env file
  // Do not expose this in UI.
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String geminiModel = 'gemini-2.5-flash';
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  static Future<FlashcardDeck> generateDeck({
    required String roadmapName,
    required String topicLabel,
    required List<String> completedTopics,
    required Set<FlashcardQuestionType> questionTypes,
    required FlashcardSourceType sourceType,
    String notes = '',
    String youtubeTranscriptUrl = '',
  }) async {
    final checkedTopics = completedTopics
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    if (checkedTopics.isEmpty) {
      throw StateError('No completed topics found for quiz generation.');
    }

    if (geminiApiKey == 'PASTE_YOUR_GEMINI_API_KEY_HERE' ||
        geminiApiKey.isEmpty) {
      throw StateError(
        'Gemini API key is missing. Set AiFlashcardService.geminiApiKey in code.',
      );
    }

    final activeTypes = questionTypes.isEmpty
        ? {
            FlashcardQuestionType.qa,
            FlashcardQuestionType.fillInBlank,
            FlashcardQuestionType.trueFalse,
            FlashcardQuestionType.codeOutput,
          }
        : questionTypes;

    final rawCards = await _generateWithGemini(
      roadmapName: roadmapName,
      topicLabel: topicLabel,
      completedTopics: checkedTopics,
      questionTypes: activeTypes,
      notes: notes,
      youtubeTranscriptUrl: youtubeTranscriptUrl,
    );

    final allowedTopicsLower = checkedTopics
        .map((t) => t.toLowerCase())
        .toSet();
    final cards = <FlashcardCard>[];
    for (final c in rawCards) {
      if (!allowedTopicsLower.contains(c.topic.toLowerCase())) {
        continue;
      }
      cards.add(
        FlashcardCard(question: c.question, answer: c.answer, type: c.type),
      );
    }

    if (cards.isEmpty) {
      throw StateError(
        'Gemini returned no valid cards for checked topics. Try again.',
      );
    }

    return FlashcardDeck(
      title: '${checkedTopics.length} Topics Quick Quiz',
      topic: checkedTopics.join(', '),
      sourceLabel: _sourceLabel(sourceType),
      cards: cards.take(12).toList(),
      createdAt: DateTime.now(),
    );
  }

  static Future<List<_GeminiCard>> _generateWithGemini({
    required String roadmapName,
    required String topicLabel,
    required List<String> completedTopics,
    required Set<FlashcardQuestionType> questionTypes,
    required String notes,
    required String youtubeTranscriptUrl,
  }) async {
    final typeList = questionTypes.map(_typeToPromptLabel).join(', ');
    final topicsList = completedTopics
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    final requestPrompt =
        '''
You are generating flashcard quiz items for a learning app.

CRITICAL RULES:
- Use ONLY these checked topics. Do not include any other topic:
$topicsList
- Every item must be tied to exactly one topic from the list above.
- Allowed question types: $typeList
- Return strictly valid JSON only. No markdown, no extra text.

Output format:
{
  "cards": [
    {
      "topic": "exact topic from checked list",
      "type": "qa|fillInBlank|trueFalse|codeOutput",
      "question": "...",
      "answer": "..."
    }
  ]
}

Generate 10 cards total with balanced coverage across checked topics.
Roadmap: $roadmapName
Current focus label (context only): $topicLabel
Optional notes (may include noise; ignore unrelated info): $notes
Optional transcript URL (context only): $youtubeTranscriptUrl
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$geminiModel:generateContent?key=$geminiApiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': requestPrompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
      },
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Gemini request failed (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw StateError('Gemini returned no candidates.');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw StateError('Gemini returned empty content.');
      }

      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw StateError('Gemini response text is empty.');
      }

      final cleanedJson = _extractJsonPayload(text);
      final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;
      final list = parsed['cards'] as List?;
      if (list == null || list.isEmpty) {
        throw StateError('Gemini JSON has no cards.');
      }

      return list
          .map((item) => _GeminiCard.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Gemini failed, falling back to Groq: $e');
      if (groqApiKey.isEmpty) throw StateError('Groq API key missing for fallback.');
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': requestPrompt}],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String;
        final cleanedJson = _extractJsonPayload(text);
        final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;
        final list = parsed['cards'] as List?;
        if (list == null || list.isEmpty) throw StateError('Groq JSON has no cards.');
        return list.map((item) => _GeminiCard.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        throw StateError('Groq fallback failed: ${response.body}');
      }
    }

  }

  /// Generate an assessment-style deck for a chosen skill/role.
  /// Difficulty is baked into the prompt as "medium-hard" and the
  /// caller may request a specific number of questions.
  static Future<AssessmentDeck> generateAssessmentDeck({
    required String roadmapName,
    required String skillOrRole,
    required List<String> topics,
    int numQuestions = 10,
    Set<FlashcardQuestionType>? questionTypes,
  }) async {
    final cleanedTopics = topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    if (cleanedTopics.isEmpty) {
      throw StateError('No topics provided for assessment generation.');
    }

    if (geminiApiKey == 'PASTE_YOUR_GEMINI_API_KEY_HERE' ||
        geminiApiKey.isEmpty) {
      throw StateError(
        'Gemini API key is missing. Set AiFlashcardService.geminiApiKey in code.',
      );
    }

    final activeTypes = questionTypes == null || questionTypes.isEmpty
        ? {
            FlashcardQuestionType.qa,
            FlashcardQuestionType.fillInBlank,
            FlashcardQuestionType.trueFalse,
          }
        : questionTypes;

    final raw = await _generateAssessmentWithGemini(
      roadmapName: roadmapName,
      skillOrRole: skillOrRole,
      topics: cleanedTopics,
      questionTypes: activeTypes,
      numQuestions: numQuestions,
    );

    final allowedTopicsLower = cleanedTopics.map((t) => t.toLowerCase()).toSet();
    final questions = <AssessmentQuestion>[];
    for (final item in raw) {
      final topic = (item['topic'] ?? '').toString().trim();
      final qtext = (item['question'] ?? '').toString().trim();
      final opts = (item['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final correctIndex = item.containsKey('correctIndex') ? (item['correctIndex'] as int) : -1;
      if (topic.isEmpty || qtext.isEmpty || opts.isEmpty) continue;
      if (!allowedTopicsLower.contains(topic.toLowerCase())) continue;
      if (correctIndex < 0 || correctIndex >= opts.length) continue;
      questions.add(AssessmentQuestion(
        topic: topic,
        question: qtext,
        options: opts,
        correctIndex: correctIndex,
      ));
    }

    if (questions.isEmpty) {
      throw StateError('Gemini returned no valid assessment questions.');
    }

    return AssessmentDeck(
      title: 'Assessment: $skillOrRole',
      skillOrRole: skillOrRole,
      questions: questions.take(numQuestions).toList(),
      createdAt: DateTime.now(),
    );
  }

  static Future<PracticalProjectPack> generatePracticalProjects({
    required String roadmapName,
    required String skillOrRole,
    required List<String> topics,
  }) async {
    final cleanedTopics = topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (cleanedTopics.isEmpty) {
      throw StateError('No topics provided for practical project generation.');
    }

    if (geminiApiKey == 'PASTE_YOUR_GEMINI_API_KEY_HERE' ||
        geminiApiKey.isEmpty) {
      throw StateError(
        'Gemini API key is missing. Set AiFlashcardService.geminiApiKey in code.',
      );
    }

    final topicsList = cleanedTopics.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final prompt = '''
You are generating practical real-world projects for a learner who wants to operate like they already hold the role.

CRITICAL RULES:
- Use ONLY the topics provided below.
- Produce 3 to 4 practical projects.
- Each project must feel like a real work assignment.
- Focus on deliverables, starter steps, and the value of the task.
- Return strictly valid JSON only.

Output format:
{
  "projects": [
    {
      "title": "...",
      "rolePlayContext": "...",
      "whyItMatters": "...",
      "deliverables": ["..."],
      "starterSteps": ["..."],
      "skills": ["..."]
    }
  ]
}

Skill or role: $skillOrRole
Roadmap: $roadmapName
Topics:
$topicsList
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$geminiModel:generateContent?key=$geminiApiKey',
    );

    List? list;
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {'temperature': 0.4, 'responseMimeType': 'application/json'},
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Gemini practical project request failed (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw StateError('Gemini returned no candidates for practical projects.');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      final text = parts?.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw StateError('Gemini practical project response text is empty.');
      }

      final parsed = jsonDecode(_extractJsonPayload(text)) as Map<String, dynamic>;
      list = parsed['projects'] as List?;
      if (list == null || list.isEmpty) {
        throw StateError('Gemini returned no practical projects.');
      }
    } catch (e) {
      debugPrint('Gemini practical project failed, falling back to Groq: $e');
      if (groqApiKey.isEmpty) throw StateError('Groq API key missing for fallback.');
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String;
        final parsed = jsonDecode(_extractJsonPayload(text)) as Map<String, dynamic>;
        list = parsed['projects'] as List?;
        if (list == null || list.isEmpty) throw StateError('Groq practical project JSON has no projects.');
      } else {
        throw StateError('Groq practical project fallback failed: ${response.body}');
      }
    }

    final projects = <PracticalProject>[];
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final title = (map['title'] as String? ?? '').trim();
      final rolePlayContext = (map['rolePlayContext'] as String? ?? '').trim();
      final whyItMatters = (map['whyItMatters'] as String? ?? '').trim();
      final deliverables = (map['deliverables'] as List? ?? []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      final starterSteps = (map['starterSteps'] as List? ?? []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      final skills = (map['skills'] as List? ?? []).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      if (title.isEmpty || rolePlayContext.isEmpty || whyItMatters.isEmpty || deliverables.isEmpty || starterSteps.isEmpty) {
        continue;
      }
      projects.add(
        PracticalProject(
          title: title,
          rolePlayContext: rolePlayContext,
          whyItMatters: whyItMatters,
          deliverables: deliverables,
          starterSteps: starterSteps,
          skills: skills,
        ),
      );
    }

    if (projects.isEmpty) {
      throw StateError('Gemini returned invalid practical projects.');
    }

    return PracticalProjectPack(
      title: 'Practical Projects for $skillOrRole',
      skillOrRole: skillOrRole,
      projects: projects.take(4).toList(),
      createdAt: DateTime.now(),
    );
  }

  static Future<List<Map<String, dynamic>>> _generateAssessmentWithGemini({
    required String roadmapName,
    required String skillOrRole,
    required List<String> topics,
    required Set<FlashcardQuestionType> questionTypes,
    required int numQuestions,
  }) async {
    final typeList = questionTypes.map(_typeToPromptLabel).join(', ');
    final topicsList = topics
      .asMap()
      .entries
      .map((e) => '${e.key + 1}. ${e.value}')
      .join('\n');

    final requestPrompt = '''
You are generating an assessment quiz for a candidate applying for a role/skill.

CRITICAL RULES:\n- Use ONLY these topics listed below. Do not invent other topics.\n- Every item must be tied to exactly one topic from the list above.\n- Produce medium to hard difficulty multiple-choice questions (MCQ) with exactly one correct answer.\n- Allowed question types: $typeList\n- Return strictly valid JSON only. No markdown, no extra text.

Output format:
{
  "cards": [
    {
      "topic": "exact topic from list",
      "type": "qa|fillInBlank|trueFalse|codeOutput",
      "question": "...",
      "options": ["opt A","opt B","opt C","opt D"],
      "correctIndex": 1
    }
  ]
}

Generate $numQuestions cards total with balanced coverage across the topics list.
Context: roadmap=$roadmapName, skill_or_role=$skillOrRole
\n
Topics:
$topicsList
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$geminiModel:generateContent?key=$geminiApiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': requestPrompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.25,
        'responseMimeType': 'application/json',
      },
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Gemini assessment request failed (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw StateError('Gemini returned no candidates for assessment.');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw StateError('Gemini returned empty assessment content.');
      }

      final text = parts.first['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw StateError('Gemini assessment response text is empty.');
      }

      final cleanedJson = _extractJsonPayload(text);
      final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;
      final list = parsed['cards'] as List?;
      if (list == null || list.isEmpty) {
        throw StateError('Gemini JSON for assessment has no cards.');
      }

      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Gemini assessment failed, falling back to Groq: $e');
      if (groqApiKey.isEmpty) throw StateError('Groq API key missing for fallback.');
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': requestPrompt}],
          'temperature': 0.25,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices'][0]['message']['content'] as String;
        final cleanedJson = _extractJsonPayload(text);
        final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;
        final list = parsed['cards'] as List?;
        if (list == null || list.isEmpty) throw StateError('Groq assessment JSON has no cards.');
        return list.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw StateError('Groq assessment fallback failed: ${response.body}');
      }
    }


  }

  static Sm2CardState updateSm2Schedule({
    required Sm2CardState current,
    required int quality,
  }) {
    final q = quality.clamp(0, 5);
    final now = DateTime.now();

    int repetitions;
    int interval;
    double ef = current.easeFactor;

    if (q < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      repetitions = current.repetitions + 1;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 3;
      } else {
        interval = (current.intervalDays * ef).round().clamp(1, 3650);
      }
    }

    ef = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    if (ef < 1.3) ef = 1.3;

    return Sm2CardState(
      repetitions: repetitions,
      intervalDays: interval,
      easeFactor: ef,
      dueDate: now.add(Duration(days: interval)),
    );
  }

  static String buildShareText(
    FlashcardDeck deck,
    FlashcardSessionResult result,
  ) {
    return 'I just completed ${deck.title} in Hustlr. '
        'Accuracy: ${result.accuracyPercent.toStringAsFixed(0)}%. '
        'Points: ${result.totalPoints}. '
        'Source: ${deck.sourceLabel}.';
  }

  static String exportDeckAsJson(FlashcardDeck deck) {
    return const JsonEncoder.withIndent('  ').convert(deck.toJson());
  }

  static String _extractJsonPayload(String rawText) {
    var text = rawText.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw FormatException('No JSON object found in Gemini response.');
    }

    return text.substring(start, end + 1);
  }

  static String _sourceLabel(FlashcardSourceType source) {
    switch (source) {
      case FlashcardSourceType.roadmapTopic:
        return 'Roadmap topic';
      case FlashcardSourceType.pastedNotes:
        return 'Pasted notes';
      case FlashcardSourceType.youtubeTranscript:
        return 'YouTube transcript URL';
      case FlashcardSourceType.uploadedNotes:
        return 'Uploaded PDF/notes';
    }
  }

  static String _typeToPromptLabel(FlashcardQuestionType type) {
    switch (type) {
      case FlashcardQuestionType.qa:
        return 'qa';
      case FlashcardQuestionType.fillInBlank:
        return 'fillInBlank';
      case FlashcardQuestionType.trueFalse:
        return 'trueFalse';
      case FlashcardQuestionType.codeOutput:
        return 'codeOutput';
    }
  }

  static FlashcardQuestionType _typeFromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'qa':
      case 'q&a':
        return FlashcardQuestionType.qa;
      case 'fillinblank':
      case 'fill_in_blank':
      case 'fill in blank':
        return FlashcardQuestionType.fillInBlank;
      case 'truefalse':
      case 'true_false':
      case 'true/false':
        return FlashcardQuestionType.trueFalse;
      case 'codeoutput':
      case 'code_output':
      case 'code output':
        return FlashcardQuestionType.codeOutput;
      default:
        throw FormatException('Unknown flashcard type: $raw');
    }
  }
}

class _GeminiCard {
  final String topic;
  final FlashcardQuestionType type;
  final String question;
  final String answer;

  const _GeminiCard({
    required this.topic,
    required this.type,
    required this.question,
    required this.answer,
  });

  factory _GeminiCard.fromJson(Map<String, dynamic> json) {
    final topic = (json['topic'] as String? ?? '').trim();
    final question = (json['question'] as String? ?? '').trim();
    final answer = (json['answer'] as String? ?? '').trim();
    final typeRaw = (json['type'] as String? ?? '').trim();

    if (topic.isEmpty ||
        question.isEmpty ||
        answer.isEmpty ||
        typeRaw.isEmpty) {
      throw FormatException('Gemini card is missing required fields.');
    }

    return _GeminiCard(
      topic: topic,
      type: AiFlashcardService._typeFromString(typeRaw),
      question: question,
      answer: answer,
    );
  }
}
