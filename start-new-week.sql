-- ============================================
-- START NEW WEEK WITH VOTE CARRYOVER
-- ============================================
-- Run this script after each Friday to start the next week
--
-- What it does:
-- 1. Finds the winner from the current active week
-- 2. Creates a new week with next Friday's drop time
-- 3. Copies all candidates to new week with vote carryover:
--    - Winner's votes reset to 0 (they already cancelled)
--    - Losers' votes carry over (builds momentum)
-- 4. Deactivates old week, activates new week

-- ============================================
-- FUNCTION: Start a new week with carryover
-- ============================================
CREATE OR REPLACE FUNCTION start_new_week(
    p_drop_time TIMESTAMPTZ,           -- Next Friday noon EST
    p_voting_closes TIMESTAMPTZ        -- Next Friday midnight before
) RETURNS JSON AS $$
DECLARE
    v_current_week INTEGER;
    v_new_week INTEGER;
    v_winner_id TEXT;
    v_winner_name TEXT;
    v_winner_votes INTEGER;
    v_candidates_copied INTEGER;
BEGIN
    -- Get current active week
    SELECT week_number INTO v_current_week
    FROM weeks
    WHERE is_active = true
    LIMIT 1;

    IF v_current_week IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'No active week found');
    END IF;

    v_new_week := v_current_week + 1;

    -- Find the winner (highest votes)
    SELECT id, name, vote_count
    INTO v_winner_id, v_winner_name, v_winner_votes
    FROM candidates
    WHERE week_number = v_current_week
    ORDER BY vote_count DESC
    LIMIT 1;

    -- Create new week
    INSERT INTO weeks (week_number, drop_time, voting_closes, participant_count, confirmed_count, is_active)
    VALUES (v_new_week, p_drop_time, p_voting_closes, 0, 0, false);

    -- Copy candidates to new week with vote carryover
    -- Winner gets 0 votes, losers keep their votes
    INSERT INTO candidates (id, name, parent, type, vote_count, week_number)
    SELECT
        id,
        name,
        parent,
        type,
        CASE WHEN id = v_winner_id THEN 0 ELSE vote_count END,
        v_new_week
    FROM candidates
    WHERE week_number = v_current_week;

    GET DIAGNOSTICS v_candidates_copied = ROW_COUNT;

    -- Deactivate old week, activate new week
    UPDATE weeks SET is_active = false WHERE week_number = v_current_week;
    UPDATE weeks SET is_active = true WHERE week_number = v_new_week;

    RETURN json_build_object(
        'success', true,
        'previous_week', v_current_week,
        'new_week', v_new_week,
        'winner', v_winner_name,
        'winner_votes', v_winner_votes,
        'candidates_copied', v_candidates_copied
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION start_new_week TO authenticated;

-- ============================================
-- EXAMPLE USAGE
-- ============================================
-- To start Week 2 (run after Week 1 Friday):
--
-- SELECT start_new_week(
--     '2025-02-07T17:00:00Z',  -- Friday Feb 7 at noon EST (5pm UTC)
--     '2025-02-07T05:00:00Z'   -- Friday Feb 7 midnight EST (5am UTC)
-- );
--
-- This will:
-- - Find Week 1 winner (e.g., Netflix with 183 votes)
-- - Create Week 2 candidates:
--   - Netflix: 0 votes (reset - they cancelled)
--   - Amazon Prime: 107 votes (carried over)
--   - Disney+: 45 votes (carried over)
--   - etc.
-- - Activate Week 2

-- ============================================
-- MANUAL ALTERNATIVE (if you prefer raw SQL)
-- ============================================
-- Replace WINNER_ID and dates as needed:
--
-- -- 1. Find winner
-- SELECT id, name, vote_count FROM candidates
-- WHERE week_number = 1 ORDER BY vote_count DESC LIMIT 1;
--
-- -- 2. Create new week
-- INSERT INTO weeks (week_number, drop_time, voting_closes, is_active)
-- VALUES (2, '2025-02-07T17:00:00Z', '2025-02-07T05:00:00Z', false);
--
-- -- 3. Copy candidates with carryover (replace 'netflix' with actual winner id)
-- INSERT INTO candidates (id, name, parent, type, vote_count, week_number)
-- SELECT id, name, parent, type,
--     CASE WHEN id = 'netflix' THEN 0 ELSE vote_count END,
--     2
-- FROM candidates WHERE week_number = 1;
--
-- -- 4. Switch active week
-- UPDATE weeks SET is_active = false WHERE week_number = 1;
-- UPDATE weeks SET is_active = true WHERE week_number = 2;
