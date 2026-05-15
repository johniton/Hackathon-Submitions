-- =============================================================================
-- HUSTLR — Skill Swap Dynamic Schema
-- Run this in your Supabase SQL Editor.
-- =============================================================================

-- NOTE: This app uses a custom `users` table (not Supabase Auth).
-- The `skill_swap_users` table is keyed on the same integer ID as `users`.

-- =============================================================================

DROP TABLE IF EXISTS swap_sessions CASCADE;
DROP TABLE IF EXISTS swap_matches CASCADE;
DROP TABLE IF EXISTS user_badges CASCADE;
DROP TABLE IF EXISTS swap_badge_definitions CASCADE;
DROP TABLE IF EXISTS skill_swap_users CASCADE;

-- =============================================================================
-- 1. SKILL SWAP USERS (profile extension for the swap feature)
-- =============================================================================

CREATE TABLE IF NOT EXISTS skill_swap_users (
  id              BIGSERIAL PRIMARY KEY,
  user_id         TEXT NOT NULL UNIQUE,   -- references users.id
  name            TEXT NOT NULL,
  avatar_initials TEXT NOT NULL DEFAULT 'U',
  city            TEXT NOT NULL DEFAULT 'India',
  skills_to_offer TEXT[]  NOT NULL DEFAULT '{}',
  skills_wanted   TEXT[]  NOT NULL DEFAULT '{}',
  rating          NUMERIC(3, 1) NOT NULL DEFAULT 5.0,
  sessions_completed INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION update_skill_swap_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_skill_swap_users_updated_at ON skill_swap_users;
CREATE TRIGGER trg_skill_swap_users_updated_at
  BEFORE UPDATE ON skill_swap_users
  FOR EACH ROW EXECUTE FUNCTION update_skill_swap_users_updated_at();


-- =============================================================================
-- 2. SWAP MATCHES
-- =============================================================================

CREATE TABLE IF NOT EXISTS swap_matches (
  id              BIGSERIAL PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES skill_swap_users(user_id) ON DELETE CASCADE,
  peer_id         TEXT NOT NULL REFERENCES skill_swap_users(user_id) ON DELETE CASCADE,
  teaching_skill  TEXT NOT NULL,     -- what user_id teaches peer_id
  learning_skill  TEXT NOT NULL,     -- what peer_id teaches user_id
  match_score     NUMERIC(4, 3) NOT NULL DEFAULT 0.0,  -- 0.000 to 1.000
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'active', 'completed', 'skipped', 'disputed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, peer_id)
);

CREATE OR REPLACE FUNCTION update_swap_matches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_swap_matches_updated_at ON swap_matches;
CREATE TRIGGER trg_swap_matches_updated_at
  BEFORE UPDATE ON swap_matches
  FOR EACH ROW EXECUTE FUNCTION update_swap_matches_updated_at();


-- =============================================================================
-- 3. SWAP SESSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS swap_sessions (
  id               BIGSERIAL PRIMARY KEY,
  match_id         BIGINT NOT NULL REFERENCES swap_matches(id) ON DELETE CASCADE,
  host_user_id     TEXT NOT NULL REFERENCES skill_swap_users(user_id) ON DELETE CASCADE,
  peer_user_id     TEXT NOT NULL REFERENCES skill_swap_users(user_id) ON DELETE CASCADE,
  scheduled_at     TIMESTAMPTZ NOT NULL,
  duration_minutes INT NOT NULL DEFAULT 60,
  mode             TEXT NOT NULL DEFAULT 'video'
                   CHECK (mode IN ('video', 'chat')),
  meet_link        TEXT,
  topic_covered    TEXT NOT NULL DEFAULT 'Skill Swap Session',
  attendance       TEXT
                   CHECK (attendance IN ('attended', 'missed', 'excused')),
  host_rating      NUMERIC(3, 1),    -- rating given by the host
  peer_rating      NUMERIC(3, 1),    -- rating given by the peer
  host_feedback    TEXT,
  peer_feedback    TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- 4. SWAP BADGES
-- =============================================================================

-- Static badge definitions
CREATE TABLE IF NOT EXISTS swap_badge_definitions (
  id          TEXT PRIMARY KEY,        -- e.g. 'badge_first'
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name   TEXT NOT NULL DEFAULT 'zap',
  color_hex   TEXT NOT NULL DEFAULT '#14B8A6'
);

-- Insert default badge definitions (idempotent)
INSERT INTO swap_badge_definitions (id, title, description, icon_name, color_hex) VALUES
  ('badge_first',   'First Swap',      'Complete your first swap session',              'zap',        '#14B8A6'),
  ('badge_10',      'Session Veteran', 'Complete 10 swap sessions',                     'trophy',     '#F59E0B'),
  ('badge_cycle',   'Full Cycle',      'Complete a full swap cycle (teach + learn)',     'refresh-ccw','#4F46E5'),
  ('badge_mentor',  'Top Mentor',      'Maintain 4.8+ rating over 5 sessions',          'star',       '#A855F7')
ON CONFLICT (id) DO NOTHING;

-- Which users have earned which badges
CREATE TABLE IF NOT EXISTS user_badges (
  id         BIGSERIAL PRIMARY KEY,
  user_id    TEXT NOT NULL,
  badge_id   TEXT NOT NULL REFERENCES swap_badge_definitions(id),
  earned_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);


-- =============================================================================
-- 5. MATCHING FUNCTION
--    find_skill_matches(p_user_id BIGINT)
--    Returns ranked matches:
--    - peer wants at least one skill the caller offers
--    - peer offers at least one skill the caller wants
--    - exclude already-matched/skipped peers
-- =============================================================================

DROP FUNCTION IF EXISTS find_skill_matches(BIGINT);
DROP FUNCTION IF EXISTS find_skill_matches(TEXT);

CREATE OR REPLACE FUNCTION find_skill_matches(p_user_id TEXT)
RETURNS TABLE (
  peer_user_id        TEXT,
  peer_name           TEXT,
  peer_avatar         TEXT,
  peer_city           TEXT,
  peer_skills_offer   TEXT[],
  peer_skills_wanted  TEXT[],
  peer_rating         NUMERIC,
  peer_sessions       INT,
  teaching_skill      TEXT,      -- best skill caller can teach peer
  learning_skill      TEXT,      -- best skill peer can teach caller
  match_score         NUMERIC
) AS $$
DECLARE
  v_caller RECORD;
BEGIN
  -- Load the caller's profile
  SELECT skills_to_offer, skills_wanted
  INTO v_caller
  FROM skill_swap_users
  WHERE user_id = p_user_id;

  RETURN QUERY
  SELECT
    p.user_id                          AS peer_user_id,
    p.name                             AS peer_name,
    p.avatar_initials                  AS peer_avatar,
    p.city                             AS peer_city,
    p.skills_to_offer                  AS peer_skills_offer,
    p.skills_wanted                    AS peer_skills_wanted,
    p.rating                           AS peer_rating,
    p.sessions_completed               AS peer_sessions,
    -- Best teaching skill: first element in caller's offer that appears in peer's wanted (case-insensitive)
    (
      SELECT o
      FROM UNNEST(v_caller.skills_to_offer) o
      WHERE EXISTS (SELECT 1 FROM UNNEST(p.skills_wanted) w WHERE TRIM(LOWER(w)) = TRIM(LOWER(o)))
      LIMIT 1
    )                                  AS teaching_skill,
    -- Best learning skill: first element in peer's offer that appears in caller's wanted (case-insensitive)
    (
      SELECT po
      FROM UNNEST(p.skills_to_offer) po
      WHERE EXISTS (SELECT 1 FROM UNNEST(v_caller.skills_wanted) w WHERE TRIM(LOWER(w)) = TRIM(LOWER(po)))
      LIMIT 1
    )                                  AS learning_skill,
    -- Score = (overlapping teaching + overlapping learning) / total union, capped at 1
    LEAST(1.0,
      (
        COALESCE(ARRAY_LENGTH(
          ARRAY(
            SELECT TRIM(LOWER(x)) FROM UNNEST(v_caller.skills_to_offer) x
            INTERSECT
            SELECT TRIM(LOWER(y)) FROM UNNEST(p.skills_wanted) y
          ), 1), 0)
        +
        COALESCE(ARRAY_LENGTH(
          ARRAY(
            SELECT TRIM(LOWER(x)) FROM UNNEST(p.skills_to_offer) x
            INTERSECT
            SELECT TRIM(LOWER(y)) FROM UNNEST(v_caller.skills_wanted) y
          ), 1), 0)
      )::NUMERIC
      / GREATEST(1,
          COALESCE(ARRAY_LENGTH(v_caller.skills_to_offer, 1), 0)
          + COALESCE(ARRAY_LENGTH(v_caller.skills_wanted, 1), 0)
        )
    )                                  AS match_score

  FROM skill_swap_users p
  WHERE
    p.user_id <> p_user_id
    -- peer must want something caller offers (case insensitive)
    AND EXISTS (
      SELECT 1 FROM UNNEST(v_caller.skills_to_offer) o
      WHERE EXISTS (SELECT 1 FROM UNNEST(p.skills_wanted) w WHERE TRIM(LOWER(w)) = TRIM(LOWER(o)))
    )
    -- peer must offer something caller wants (case insensitive)
    AND EXISTS (
      SELECT 1 FROM UNNEST(p.skills_to_offer) po
      WHERE EXISTS (SELECT 1 FROM UNNEST(v_caller.skills_wanted) w WHERE TRIM(LOWER(w)) = TRIM(LOWER(po)))
    )
    -- exclude already matched / skipped
    AND NOT EXISTS (
      SELECT 1 FROM swap_matches m
      WHERE (m.user_id = p_user_id AND m.peer_id = p.user_id)
         OR (m.user_id = p.user_id AND m.peer_id = p_user_id)
    )
  ORDER BY match_score DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE;


-- =============================================================================
-- 6. TRIGGER — Auto-award badges after session updates
-- =============================================================================

CREATE OR REPLACE FUNCTION award_badges_on_session()
RETURNS TRIGGER AS $$
DECLARE
  v_host_sessions INT;
  v_host_rating   NUMERIC;
BEGIN
  -- Only run when attendance is set to 'attended'
  IF NEW.attendance = 'attended' AND (OLD.attendance IS DISTINCT FROM 'attended') THEN

    -- Increment sessions_completed for both participants
    UPDATE skill_swap_users SET sessions_completed = sessions_completed + 1
    WHERE user_id = NEW.host_user_id OR user_id = NEW.peer_user_id;

    -- Check host for badge eligibility
    SELECT sessions_completed, rating
    INTO v_host_sessions, v_host_rating
    FROM skill_swap_users WHERE user_id = NEW.host_user_id;

    -- Badge: First Swap
    IF v_host_sessions >= 1 THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (NEW.host_user_id, 'badge_first')
      ON CONFLICT DO NOTHING;

      INSERT INTO user_badges (user_id, badge_id)
      VALUES (NEW.peer_user_id, 'badge_first')
      ON CONFLICT DO NOTHING;
    END IF;

    -- Badge: Session Veteran
    IF v_host_sessions >= 10 THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (NEW.host_user_id, 'badge_10')
      ON CONFLICT DO NOTHING;
    END IF;

    -- Badge: Top Mentor (host)
    IF v_host_sessions >= 5 AND v_host_rating >= 4.8 THEN
      INSERT INTO user_badges (user_id, badge_id)
      VALUES (NEW.host_user_id, 'badge_mentor')
      ON CONFLICT DO NOTHING;
    END IF;

  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_award_badges ON swap_sessions;
CREATE TRIGGER trg_award_badges
  AFTER UPDATE ON swap_sessions
  FOR EACH ROW EXECUTE FUNCTION award_badges_on_session();


-- =============================================================================
-- 7. TRIGGER — Recalculate user rating after a session rating is submitted
-- =============================================================================

CREATE OR REPLACE FUNCTION recalculate_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate rating for peer (who was rated by host)
  IF NEW.host_rating IS NOT NULL AND OLD.host_rating IS DISTINCT FROM NEW.host_rating THEN
    UPDATE skill_swap_users
    SET rating = (
      SELECT COALESCE(AVG(r), 5.0)
      FROM (
        SELECT host_rating AS r FROM swap_sessions
        WHERE peer_user_id = NEW.peer_user_id AND host_rating IS NOT NULL
        UNION ALL
        SELECT peer_rating AS r FROM swap_sessions
        WHERE host_user_id = NEW.peer_user_id AND peer_rating IS NOT NULL
      ) ratings
    )
    WHERE user_id = NEW.peer_user_id;
  END IF;

  -- Recalculate rating for host (who was rated by peer)
  IF NEW.peer_rating IS NOT NULL AND OLD.peer_rating IS DISTINCT FROM NEW.peer_rating THEN
    UPDATE skill_swap_users
    SET rating = (
      SELECT COALESCE(AVG(r), 5.0)
      FROM (
        SELECT peer_rating AS r FROM swap_sessions
        WHERE host_user_id = NEW.host_user_id AND peer_rating IS NOT NULL
        UNION ALL
        SELECT host_rating AS r FROM swap_sessions
        WHERE peer_user_id = NEW.host_user_id AND host_rating IS NOT NULL
      ) ratings
    )
    WHERE user_id = NEW.host_user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recalculate_rating ON swap_sessions;
CREATE TRIGGER trg_recalculate_rating
  AFTER UPDATE ON swap_sessions
  FOR EACH ROW EXECUTE FUNCTION recalculate_user_rating();


-- =============================================================================
-- 8. SAMPLE SEED DATA (for testing — delete in production)
-- =============================================================================
-- Assumes users table already has IDs 1, 2, 3, 4, 5.
-- Comment this out once you have real users.

INSERT INTO skill_swap_users (user_id, name, avatar_initials, city, skills_to_offer, skills_wanted) VALUES
  ('1', 'You',          'Y', 'Goa',       ARRAY['Flutter', 'Dart', 'Firebase'],        ARRAY['React Native', 'Node.js', 'UI/UX']),
  ('2', 'Priya Sharma', 'P', 'Mumbai',    ARRAY['React Native', 'TypeScript'],          ARRAY['Flutter', 'Firebase']),
  ('3', 'Arjun Mehta',  'A', 'Bangalore', ARRAY['Machine Learning', 'Python'],          ARRAY['Flutter', 'Dart']),
  ('4', 'Zara Khan',    'Z', 'Delhi',     ARRAY['UI/UX', 'Figma'],                      ARRAY['Node.js', 'REST APIs']),
  ('5', 'Rohan Verma',  'R', 'Pune',      ARRAY['Node.js', 'REST APIs', 'TypeScript'], ARRAY['Flutter', 'Firebase', 'Dart'])
ON CONFLICT (user_id) DO NOTHING;
