-- real_analysis.sql
-- Part A: queries on my own gameplay log (one non-spending player, levels 1-33).
-- Engine: SQLite (DB Browser for SQLite). Window functions need SQLite 3.25 or newer.
--
-- Table: attempts
--   level, result ('win'/'lose'), goal_remaining_pct, spectacle, fomo_prompt (0/1),
--   after_loss ('R' replayed / 'Q' ended session), assumed (0/1), note
--
-- Note: "first attempt per level" relies on rowid order, so keep attempts.csv
-- in chronological order when importing.


-- ---------------------------------------------------------------------------
-- 0. SETUP (run once; skip if the column already exists)
-- ---------------------------------------------------------------------------
ALTER TABLE attempts ADD COLUMN level_type TEXT DEFAULT 'regular';

UPDATE attempts
SET level_type = 'tutorial_or_interlude'
WHERE level IN (7, 21, 28, 32);


-- ---------------------------------------------------------------------------
-- Q1. First-attempt wins by level band (all levels)
-- Expected: 1-23 -> 23 levels, 20 wins; 24-33 -> 10 levels, 4 wins
-- ---------------------------------------------------------------------------
WITH numbered AS (
  SELECT level, result,
         ROW_NUMBER() OVER (PARTITION BY level ORDER BY rowid) AS rn
  FROM attempts
)
SELECT CASE WHEN level < 24 THEN '1-23' ELSE '24-33' END AS band,
       COUNT(*)                                          AS levels,
       SUM(result = 'win')                               AS first_try_wins
FROM numbered
WHERE rn = 1
GROUP BY band;


-- ---------------------------------------------------------------------------
-- Q2. Loss density by level band (all levels)
-- Expected: 1-23 -> 4 losses; 24-33 -> 11 losses
-- ---------------------------------------------------------------------------
SELECT CASE WHEN level < 24 THEN '1-23' ELSE '24-33' END AS band,
       COUNT(DISTINCT level)                             AS levels,
       SUM(result = 'lose')                              AS losses,
       ROUND(1.0 * SUM(result = 'lose') / COUNT(DISTINCT level), 2) AS losses_per_level
FROM attempts
GROUP BY band;


-- ---------------------------------------------------------------------------
-- Q3. Near-miss (25% or less of the goal left) vs larger miss: did I replay?
-- Expected: bigger_miss -> 3 losses, 2 replayed; near_miss -> 6 losses, 4 replayed
-- ---------------------------------------------------------------------------
SELECT CASE WHEN goal_remaining_pct <= 25 THEN 'near_miss' ELSE 'bigger_miss' END AS loss_type,
       COUNT(*)                  AS losses,
       SUM(after_loss = 'R')     AS replayed
FROM attempts
WHERE result = 'lose'
  AND goal_remaining_pct IS NOT NULL
  AND goal_remaining_pct != ''
GROUP BY loss_type;


-- ---------------------------------------------------------------------------
-- Q4. Loss-framed second offer screen vs session ending after a loss
-- Expected: fomo_prompt 0 -> 11 losses, 1 session ended; fomo_prompt 1 -> 4 losses, 2 ended
-- Caveat: the screen appeared on every loss from level 27 on, so this is
-- confounded with level.
-- ---------------------------------------------------------------------------
SELECT fomo_prompt,
       COUNT(*)                  AS losses,
       SUM(after_loss = 'Q')     AS session_ended
FROM attempts
WHERE result = 'lose'
GROUP BY fomo_prompt;


-- ---------------------------------------------------------------------------
-- S1. Sensitivity: first-attempt wins, regular levels only
-- Expected: 1-23 -> 21 levels, 18 wins; 24-33 -> 8 levels, 2 wins
-- ---------------------------------------------------------------------------
WITH numbered AS (
  SELECT level, result,
         ROW_NUMBER() OVER (PARTITION BY level ORDER BY rowid) AS rn
  FROM attempts
  WHERE level_type = 'regular'
)
SELECT CASE WHEN level < 24 THEN '1-23' ELSE '24-33' END AS band,
       COUNT(*)                                          AS levels,
       SUM(result = 'win')                               AS first_try_wins
FROM numbered
WHERE rn = 1
GROUP BY band;


-- ---------------------------------------------------------------------------
-- S2. Sensitivity: loss density, regular levels only
-- Expected: 1-23 -> 21 levels, 4 losses (0.19); 24-33 -> 8 levels, 11 losses (1.38)
-- ---------------------------------------------------------------------------
SELECT CASE WHEN level < 24 THEN '1-23' ELSE '24-33' END AS band,
       COUNT(DISTINCT level)                             AS levels,
       SUM(result = 'lose')                              AS losses,
       ROUND(1.0 * SUM(result = 'lose') / COUNT(DISTINCT level), 2) AS losses_per_level
FROM attempts
WHERE level_type = 'regular'
GROUP BY band;


-- ---------------------------------------------------------------------------
-- E1. Near-miss threshold sensitivity (20% or less left)
-- Expected: near_miss -> 5 losses, 4 replayed; bigger_miss -> 4 losses, 2 replayed
-- ---------------------------------------------------------------------------
SELECT CASE WHEN goal_remaining_pct <= 20 THEN 'near_miss_20' ELSE 'bigger_miss_20' END AS loss_type,
       COUNT(*)                  AS losses,
       SUM(after_loss = 'R')     AS replayed
FROM attempts
WHERE result = 'lose'
  AND goal_remaining_pct IS NOT NULL
  AND goal_remaining_pct != ''
GROUP BY loss_type;


-- ---------------------------------------------------------------------------
-- E2. Spectacle level vs result (weak, self-labelled; see findings.md)
-- ---------------------------------------------------------------------------
SELECT spectacle,
       COUNT(*)                  AS attempts,
       SUM(result = 'win')       AS wins
FROM attempts
GROUP BY spectacle;


-- ---------------------------------------------------------------------------
-- C1. Chart data: losses per level (feeds charts/difficulty_ramp.png)
-- ---------------------------------------------------------------------------
SELECT level,
       MAX(level_type)           AS level_type,
       SUM(result = 'lose')      AS losses
FROM attempts
GROUP BY level
ORDER BY level;
