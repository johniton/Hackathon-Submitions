-- ============================================================
-- Hustlr AI Interview — Complete Supabase Schema
-- Run this entire file in your Supabase SQL Editor
-- ============================================================

-- ─── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ─── ENUMs ───────────────────────────────────────────────────

CREATE TYPE interview_status AS ENUM (
    'CREATED',
    'IN_PROGRESS',
    'SUBMITTED',
    'PROCESSING',
    'SCORED',
    'COMPLETED',
    'FAILED'
);

CREATE TYPE performance_tier AS ENUM (
    'EXCELLENT',
    'GOOD',
    'NEEDS_IMPROVEMENT',
    'POOR'
);

CREATE TYPE interview_type AS ENUM (
    'TECHNICAL',
    'HR',
    'MIXED'
);

CREATE TYPE difficulty_level AS ENUM (
    'JUNIOR',
    'MID',
    'SENIOR'
);


-- ─── Interview Sessions ─────────────────────────────────────
CREATE TABLE interview_sessions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                 TEXT,
    job_role                TEXT NOT NULL,
    target_companies        TEXT[] NOT NULL DEFAULT '{}',
    interview_type          interview_type NOT NULL DEFAULT 'MIXED',
    difficulty              difficulty_level NOT NULL DEFAULT 'MID',
    company_context         TEXT,
    context_sources         JSONB DEFAULT '[]'::jsonb,
    status                  interview_status NOT NULL DEFAULT 'CREATED',
    started_at              TIMESTAMPTZ,
    submitted_at            TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    total_questions_asked   INTEGER DEFAULT 0,
    ai_stop_reason          TEXT,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_user     ON interview_sessions(user_id);
CREATE INDEX idx_sessions_status   ON interview_sessions(status);
CREATE INDEX idx_sessions_created  ON interview_sessions(created_at DESC);
CREATE INDEX idx_sessions_role     ON interview_sessions(job_role);


-- ─── Interview Questions ─────────────────────────────────────
CREATE TABLE interview_questions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
    question_text   TEXT NOT NULL,
    order_index     INTEGER NOT NULL,
    question_type   TEXT DEFAULT 'standard',
    areas_covered   TEXT[] DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_questions_session ON interview_questions(session_id);
CREATE INDEX idx_questions_order   ON interview_questions(session_id, order_index);


-- ─── Interview Answers ───────────────────────────────────────
CREATE TABLE interview_answers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_id         UUID NOT NULL REFERENCES interview_questions(id) ON DELETE CASCADE,
    session_id          UUID NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
    video_url           TEXT,
    video_local_path    TEXT,
    transcript          TEXT,
    stt_engine          TEXT,
    stt_uncertainty     BOOLEAN DEFAULT FALSE,
    score_relevance     NUMERIC(4,2),
    score_completeness  NUMERIC(4,2),
    score_clarity       NUMERIC(4,2),
    score_confidence    NUMERIC(4,2),
    key_points_covered  JSONB DEFAULT '[]'::jsonb,
    notable_gaps        JSONB DEFAULT '[]'::jsonb,
    scoring_explanation TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_answers_session  ON interview_answers(session_id);
CREATE INDEX idx_answers_question ON interview_answers(question_id);


-- ─── Interview Assessments ───────────────────────────────────
CREATE TABLE interview_assessments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id              UUID NOT NULL UNIQUE REFERENCES interview_sessions(id) ON DELETE CASCADE,
    composite_score         NUMERIC(5,2),
    confidence_interval     NUMERIC(5,2),
    performance_tier        performance_tier,
    tier_rationale          TEXT,
    upskilling_areas        JSONB DEFAULT '[]'::jsonb,
    strong_areas            JSONB DEFAULT '[]'::jsonb,
    recommended_resources   JSONB DEFAULT '[]'::jsonb,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assessments_session ON interview_assessments(session_id);
CREATE INDEX idx_assessments_tier    ON interview_assessments(performance_tier);
CREATE INDEX idx_assessments_score   ON interview_assessments(composite_score DESC);


-- ─── Triggers ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_interview_sessions_updated_at
    BEFORE UPDATE ON interview_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_interview_assessments_updated_at
    BEFORE UPDATE ON interview_assessments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ─── RLS Policies ────────────────────────────────────────────

ALTER TABLE interview_sessions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE interview_questions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE interview_answers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE interview_assessments ENABLE ROW LEVEL SECURITY;

-- Service role (backend) full access
CREATE POLICY "service_all_sessions"    ON interview_sessions    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_all_questions"   ON interview_questions   FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_all_answers"     ON interview_answers     FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_all_assessments" ON interview_assessments FOR ALL USING (auth.role() = 'service_role');

-- Authenticated users read own data
CREATE POLICY "user_read_own_sessions" ON interview_sessions FOR SELECT
    USING (auth.role() = 'authenticated' AND user_id = auth.uid()::text);

CREATE POLICY "user_read_own_questions" ON interview_questions FOR SELECT
    USING (auth.role() = 'authenticated' AND session_id IN (
        SELECT id FROM interview_sessions WHERE user_id = auth.uid()::text
    ));

CREATE POLICY "user_read_own_answers" ON interview_answers FOR SELECT
    USING (auth.role() = 'authenticated' AND session_id IN (
        SELECT id FROM interview_sessions WHERE user_id = auth.uid()::text
    ));

CREATE POLICY "user_read_own_assessments" ON interview_assessments FOR SELECT
    USING (auth.role() = 'authenticated' AND session_id IN (
        SELECT id FROM interview_sessions WHERE user_id = auth.uid()::text
    ));


-- ─── Storage Bucket ──────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'interview-videos',
    'interview-videos',
    false,
    104857600,
    ARRAY['video/mp4', 'video/webm', 'video/quicktime', 'audio/wav', 'audio/mpeg']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "service_all_interview_videos" ON storage.objects FOR ALL
    USING (bucket_id = 'interview-videos' AND auth.role() = 'service_role');

CREATE POLICY "user_read_own_videos" ON storage.objects FOR SELECT
    USING (
        bucket_id = 'interview-videos'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] IN (
            SELECT id::text FROM interview_sessions WHERE user_id = auth.uid()::text
        )
    );


-- ─── Views ───────────────────────────────────────────────────

CREATE OR REPLACE VIEW interview_full_result AS
SELECT
    s.id AS session_id, s.user_id, s.job_role, s.target_companies,
    s.interview_type, s.difficulty, s.status, s.total_questions_asked,
    s.created_at AS interview_date,
    a.composite_score, a.confidence_interval, a.performance_tier,
    a.tier_rationale, a.upskilling_areas, a.strong_areas, a.recommended_resources
FROM interview_sessions s
LEFT JOIN interview_assessments a ON s.id = a.session_id;

CREATE OR REPLACE VIEW interview_qa_breakdown AS
SELECT
    q.session_id, q.id AS question_id, q.order_index, q.question_text, q.question_type,
    ans.transcript, ans.stt_uncertainty,
    ans.score_relevance, ans.score_completeness, ans.score_clarity, ans.score_confidence,
    ans.key_points_covered, ans.notable_gaps, ans.scoring_explanation,
    ROUND(
        (COALESCE(ans.score_relevance,5)*0.30 + COALESCE(ans.score_completeness,5)*0.25 +
         COALESCE(ans.score_clarity,5)*0.25 + COALESCE(ans.score_confidence,5)*0.20) * 10,
    2) AS question_composite
FROM interview_questions q
LEFT JOIN interview_answers ans ON ans.question_id = q.id
ORDER BY q.session_id, q.order_index;
