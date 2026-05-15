/// Hustlr AI Interview — Data Models
/// Dart data classes mirroring backend schemas.

class InterviewSetup {
  final String? userId;
  final String jobRole;
  final List<String> targetCompanies;
  final String interviewType; // TECHNICAL | HR | MIXED
  final String difficulty; // JUNIOR | MID | SENIOR
  final String? screeningContext;
  final List<String>? customQuestions;

  InterviewSetup({
    this.userId,
    required this.jobRole,
    this.targetCompanies = const [],
    this.interviewType = 'MIXED',
    this.difficulty = 'MID',
    this.screeningContext,
    this.customQuestions,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId ?? 'anonymous',
        'job_role': jobRole,
        'target_companies': targetCompanies,
        'interview_type': interviewType,
        'difficulty': difficulty,
        if (screeningContext != null) 'screening_context': screeningContext,
        if (customQuestions != null) 'custom_questions': customQuestions,
      };
}

class QuestionItem {
  final String? id;
  final int order;
  final String questionText;
  final List<String>? areasCovered;

  QuestionItem({
    this.id,
    required this.order,
    required this.questionText,
    this.areasCovered,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) => QuestionItem(
        id: json['id']?.toString(),
        order: json['order'] ?? 1,
        questionText: json['question_text'] ?? '',
        areasCovered: json['areas_covered'] != null
            ? List<String>.from(json['areas_covered'])
            : null,
      );
}

class InterviewStartResult {
  final String sessionId;
  final List<QuestionItem> questions;
  final String? companyContextSummary;
  final String message;

  InterviewStartResult({
    required this.sessionId,
    required this.questions,
    this.companyContextSummary,
    required this.message,
  });

  factory InterviewStartResult.fromJson(Map<String, dynamic> json) =>
      InterviewStartResult(
        sessionId: json['session_id'] ?? '',
        questions: (json['questions'] as List? ?? [])
            .map((q) => QuestionItem.fromJson(q))
            .toList(),
        companyContextSummary: json['company_context_summary'],
        message: json['message'] ?? '',
      );
}

class SubmitResult {
  final bool success;
  final String? answerId;
  final QuestionItem? nextQuestion;
  final String message;

  SubmitResult({
    required this.success,
    this.answerId,
    this.nextQuestion,
    required this.message,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> json) => SubmitResult(
        success: json['success'] ?? false,
        answerId: json['answer_id'],
        nextQuestion: json['next_question'] != null
            ? QuestionItem.fromJson(json['next_question'])
            : null,
        message: json['message'] ?? '',
      );
}

class QuestionScore {
  final String questionId;
  final String questionText;
  final int order;
  final double? relevance;
  final double? completeness;
  final double? clarity;
  final double? confidence;
  final String? transcript;
  final String? explanation;

  QuestionScore({
    required this.questionId,
    required this.questionText,
    required this.order,
    this.relevance,
    this.completeness,
    this.clarity,
    this.confidence,
    this.transcript,
    this.explanation,
  });

  factory QuestionScore.fromJson(Map<String, dynamic> json) => QuestionScore(
        questionId: json['question_id'] ?? '',
        questionText: json['question_text'] ?? '',
        order: json['order'] ?? 0,
        relevance: (json['relevance'] as num?)?.toDouble(),
        completeness: (json['completeness'] as num?)?.toDouble(),
        clarity: (json['clarity'] as num?)?.toDouble(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        transcript: json['transcript'],
        explanation: json['explanation'],
      );
}

class InterviewResult {
  final String sessionId;
  final String status;
  final double? compositeScore;
  final double? confidenceInterval;
  final String? performanceTier;
  final String? tierRationale;
  final List<String>? upskillingAreas;
  final List<String>? strongAreas;
  final List<QuestionScore>? perQuestionScores;
  final bool processingComplete;

  InterviewResult({
    required this.sessionId,
    required this.status,
    this.compositeScore,
    this.confidenceInterval,
    this.performanceTier,
    this.tierRationale,
    this.upskillingAreas,
    this.strongAreas,
    this.perQuestionScores,
    required this.processingComplete,
  });

  factory InterviewResult.fromJson(Map<String, dynamic> json) =>
      InterviewResult(
        sessionId: json['session_id'] ?? '',
        status: json['status'] ?? '',
        compositeScore: (json['composite_score'] as num?)?.toDouble(),
        confidenceInterval: (json['confidence_interval'] as num?)?.toDouble(),
        performanceTier: json['performance_tier'],
        tierRationale: json['tier_rationale'],
        upskillingAreas: json['upskilling_areas'] != null
            ? List<String>.from(json['upskilling_areas'])
            : null,
        strongAreas: json['strong_areas'] != null
            ? List<String>.from(json['strong_areas'])
            : null,
        perQuestionScores: json['per_question_scores'] != null
            ? (json['per_question_scores'] as List)
                .map((q) => QuestionScore.fromJson(q))
                .toList()
            : null,
        processingComplete: json['processing_complete'] ?? false,
      );
}
