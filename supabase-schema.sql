-- SALT Database Schema for Supabase
-- Run this in the Supabase SQL Editor

-- Table for tracking weeks/campaigns
-- The target is determined by votes, not pre-set
CREATE TABLE weeks (
    id SERIAL PRIMARY KEY,
    week_number INTEGER UNIQUE NOT NULL,
    drop_time TIMESTAMPTZ NOT NULL,
    voting_closes TIMESTAMPTZ NOT NULL,
    participant_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for tracking vote candidates
CREATE TABLE candidates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent TEXT NOT NULL,
    type TEXT NOT NULL,
    vote_count INTEGER DEFAULT 0,
    week_number INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table for fingerprint tracking (prevents duplicate votes/commits)
-- We only store hashed fingerprints, no personal data
CREATE TABLE user_actions (
    id SERIAL PRIMARY KEY,
    fingerprint_hash TEXT NOT NULL,
    week_number INTEGER NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('commit', 'vote')),
    candidate_id TEXT, -- only for votes
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(fingerprint_hash, week_number, action_type)
);

-- Index for fast lookups
CREATE INDEX idx_user_actions_lookup ON user_actions(fingerprint_hash, week_number, action_type);
CREATE INDEX idx_candidates_week ON candidates(week_number);

-- Enable Row Level Security
ALTER TABLE weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_actions ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read access to weeks and candidates
CREATE POLICY "Anyone can read weeks" ON weeks FOR SELECT USING (true);
CREATE POLICY "Anyone can read candidates" ON candidates FOR SELECT USING (true);

-- Allow anonymous insert to user_actions (but not read others' data)
CREATE POLICY "Anyone can insert actions" ON user_actions FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can check own actions" ON user_actions FOR SELECT USING (true);

-- Function to commit to a week (atomic increment + duplicate check)
CREATE OR REPLACE FUNCTION commit_to_week(
    p_fingerprint_hash TEXT,
    p_week_number INTEGER
) RETURNS JSON AS $$
DECLARE
    v_existing BOOLEAN;
    v_new_count INTEGER;
BEGIN
    -- Check if already committed
    SELECT EXISTS(
        SELECT 1 FROM user_actions
        WHERE fingerprint_hash = p_fingerprint_hash
        AND week_number = p_week_number
        AND action_type = 'commit'
    ) INTO v_existing;

    IF v_existing THEN
        RETURN json_build_object('success', false, 'error', 'already_committed');
    END IF;

    -- Insert the action
    INSERT INTO user_actions (fingerprint_hash, week_number, action_type)
    VALUES (p_fingerprint_hash, p_week_number, 'commit');

    -- Increment the count
    UPDATE weeks
    SET participant_count = participant_count + 1
    WHERE week_number = p_week_number
    RETURNING participant_count INTO v_new_count;

    RETURN json_build_object('success', true, 'new_count', v_new_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to vote for a candidate (atomic increment + duplicate check)
CREATE OR REPLACE FUNCTION vote_for_candidate(
    p_fingerprint_hash TEXT,
    p_week_number INTEGER,
    p_candidate_id TEXT
) RETURNS JSON AS $$
DECLARE
    v_existing BOOLEAN;
    v_new_count INTEGER;
BEGIN
    -- Check if already voted this week
    SELECT EXISTS(
        SELECT 1 FROM user_actions
        WHERE fingerprint_hash = p_fingerprint_hash
        AND week_number = p_week_number
        AND action_type = 'vote'
    ) INTO v_existing;

    IF v_existing THEN
        RETURN json_build_object('success', false, 'error', 'already_voted');
    END IF;

    -- Insert the action
    INSERT INTO user_actions (fingerprint_hash, week_number, action_type, candidate_id)
    VALUES (p_fingerprint_hash, p_week_number, 'vote', p_candidate_id);

    -- Increment the vote count
    UPDATE candidates
    SET vote_count = vote_count + 1
    WHERE id = p_candidate_id AND week_number = p_week_number
    RETURNING vote_count INTO v_new_count;

    RETURN json_build_object('success', true, 'new_count', v_new_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check user's actions for a week
CREATE OR REPLACE FUNCTION get_user_actions(
    p_fingerprint_hash TEXT,
    p_week_number INTEGER
) RETURNS JSON AS $$
DECLARE
    v_committed BOOLEAN;
    v_voted_for TEXT;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM user_actions
        WHERE fingerprint_hash = p_fingerprint_hash
        AND week_number = p_week_number
        AND action_type = 'commit'
    ) INTO v_committed;

    SELECT candidate_id FROM user_actions
    WHERE fingerprint_hash = p_fingerprint_hash
    AND week_number = p_week_number
    AND action_type = 'vote'
    INTO v_voted_for;

    RETURN json_build_object(
        'committed', v_committed,
        'voted_for', v_voted_for
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION commit_to_week TO anon;
GRANT EXECUTE ON FUNCTION vote_for_candidate TO anon;
GRANT EXECUTE ON FUNCTION get_user_actions TO anon;

-- Enable realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE weeks;
ALTER PUBLICATION supabase_realtime ADD TABLE candidates;

-- Insert Week 1 data
-- Voting closes Thursday midnight, action is Friday noon EST (5pm UTC)
INSERT INTO weeks (week_number, drop_time, voting_closes, participant_count, is_active)
VALUES (1, '2025-01-31T17:00:00Z', '2025-01-31T05:00:00Z', 0, true);

-- Insert candidates for Week 1 voting (includes all options)
INSERT INTO candidates (id, name, parent, type, vote_count, week_number) VALUES
('prime', 'Amazon Prime', 'Amazon.com Inc.', 'Subscription', 0, 1),
('netflix', 'Netflix', 'Netflix Inc.', 'Streaming', 0, 1),
('appletv', 'Apple TV+', 'Apple Inc.', 'Streaming', 0, 1),
('disney', 'Disney+', 'The Walt Disney Company', 'Streaming', 0, 1),
('spotify', 'Spotify Premium', 'Spotify AB', 'Subscription', 0, 1),
('hulu', 'Hulu', 'The Walt Disney Company', 'Streaming', 0, 1),
('max', 'Max', 'Warner Bros. Discovery', 'Streaming', 0, 1),
('paramount', 'Paramount+', 'Paramount Global', 'Streaming', 0, 1),
('youtube', 'YouTube Premium', 'Alphabet Inc.', 'Subscription', 0, 1),
('uber', 'Uber One', 'Uber Technologies', 'Convenience', 0, 1),
('doordash', 'DashPass', 'DoorDash Inc.', 'Convenience', 0, 1);
