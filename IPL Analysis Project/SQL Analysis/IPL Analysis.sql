-- Top Revenue Player Impact Analysis-- 

WITH players_run AS (
    SELECT 
        batter, 
        SUM(batsman_runs) AS total_runs
    FROM cricket_analysis.ball_match
    GROUP BY batter
),

mom_count AS (
    SELECT 
        man_of_match AS batter, 
        COUNT(DISTINCT match_no) AS total_prize
    FROM cricket_analysis.ball_match
    WHERE man_of_match IS NOT NULL
    GROUP BY man_of_match
)

SELECT 
    p.batter, 
    p.total_runs, 
    COALESCE(c.total_prize, 0) AS total_prize
FROM players_run p
LEFT JOIN mom_count c
ON p.batter = c.batter
ORDER BY p.total_runs DESC, total_prize DESC
LIMIT 5;

-- Toss Strategy Effectiveness Analysis--

with match_level as(
select distinct match_no , toss_won,toss_decision,winner
from cricket_analysis.ball_match)
select toss_decision , count(match_no) as total_matches,
count(case when toss_won=winner then 1 end) as total_winner,
ROUND(
        COUNT(CASE WHEN toss_won = winner THEN 1 END) * 100.0 
        / COUNT(match_no), 
        2
    ) AS win_percentage
    FROM match_level
GROUP BY toss_decision
ORDER BY win_percentage DESC;

-- Venue Profitability & Chase Advantage Analysis-- 


WITH match_info AS (
    SELECT DISTINCT
        match_no,
        venue,
        team1,
        team2,
        winner
    FROM cricket_analysis.ball_match
),

first_innings_score AS (
    SELECT
        match_no,
        SUM(score) AS first_innings_total
    FROM cricket_analysis.ball_match
    WHERE inningno = 1
    GROUP BY match_no
)

SELECT
    m.venue,
    COUNT(DISTINCT m.match_no) AS total_matches,
    
    ROUND(AVG(f.first_innings_total), 2) AS avg_first_innings_score,
    
    ROUND(
        COUNT(CASE 
                WHEN m.winner = m.team2 THEN 1 
              END) * 100.0
        / COUNT(DISTINCT m.match_no),
        2
    ) AS chasing_win_percentage

FROM match_info m
JOIN first_innings_score f 
    ON m.match_no = f.match_no

GROUP BY m.venue
ORDER BY chasing_win_percentage DESC;


-- Death Over Specialist Analysis
ALTER TABLE cricket_analysis.ball_match
CHANGE `over` over_number DOUBLE;
-- bcs  over is keyword in sql


SELECT 
    batter,
    SUM(batsman_runs) AS death_runs,
    COUNT(CASE WHEN is_extra = 0 THEN 1 END) AS balls_faced,
    ROUND(
        SUM(batsman_runs) * 100.0 /
        COUNT(CASE WHEN is_extra = 0 THEN 1 END),
        2
    ) AS strike_rate
FROM cricket_analysis.ball_match
WHERE over_number >= 16
GROUP BY batter
ORDER BY strike_rate DESC;

-- Powerplay Dominance Analysis (Overs 1–6)

WITH powerplay_runs AS (
    SELECT 
        match_no,
        team1 AS team,
        SUM(batsman_runs + is_extra) AS total_powerplay_runs
    FROM cricket_analysis.ball_match
    WHERE over_number BETWEEN 0 AND 5
    GROUP BY match_no, team1
)

SELECT 
    team,
    COUNT(match_no) AS matches_played,
    SUM(total_powerplay_runs) AS total_powerplay_runs,
    ROUND(
        SUM(total_powerplay_runs) * 1.0 / COUNT(match_no),
        2
    ) AS avg_powerplay_runs
FROM powerplay_runs
GROUP BY team
ORDER BY avg_powerplay_runs DESC;

-- Player Consistency Index Analysis

WITH player_match_runs AS (
    SELECT 
        batter,
        match_no,
        SUM(batsman_runs) AS match_runs
    FROM cricket_analysis.ball_match
    GROUP BY batter, match_no
)

SELECT 
    batter,
    COUNT(match_no) AS matches_played,
    SUM(match_runs) AS total_runs,
    
    ROUND(AVG(match_runs), 2) AS avg_runs,
    
    ROUND(STDDEV(match_runs), 2) AS consistency_index

FROM player_match_runs

GROUP BY batter

HAVING COUNT(match_no) >= 10

ORDER BY consistency_index ASC;

-- Chasing vs Defending Advantage

WITH match_data AS (
    SELECT DISTINCT
        match_no,
        toss_won,
        toss_decision,
        winner
    FROM cricket_analysis.ball_match
)

SELECT 
    win_type,
    COUNT(*) AS matches,
    ROUND(COUNT(*) * 100.0 / 
          SUM(COUNT(*)) OVER (), 2) AS percentage
FROM (
    SELECT 
        CASE 
            WHEN toss_decision = 'field' AND toss_won = winner 
                THEN 'Chasing Win'
            WHEN toss_decision = 'bat' AND toss_won = winner 
                THEN 'Defending Win'
        END AS win_type
    FROM match_data
    WHERE toss_won = winner
) sub
GROUP BY win_type;

-- Most Impactful Player in Winning Matches

WITH player_runs AS (
    SELECT 
        batter,
        match_no,
        team1 AS batting_team,   -- yaha confirm karo correct column
        SUM(batsman_runs) AS match_runs
    FROM cricket_analysis.ball_match
    GROUP BY batter, match_no, team1
)

SELECT
    batter,
    SUM(match_runs) AS total_runs,

    SUM(
        CASE 
            WHEN batting_team = winner 
            THEN match_runs 
            ELSE 0 
        END
    ) AS runs_in_wins,

    ROUND(
        SUM(
            CASE 
                WHEN batting_team = winner 
                THEN match_runs 
                ELSE 0 
            END
        ) * 100.0 / SUM(match_runs),
        2
    ) AS winning_contribution_percentage

FROM player_runs p
JOIN (
    SELECT DISTINCT match_no, winner
    FROM cricket_analysis.ball_match
) m
ON p.match_no = m.match_no

GROUP BY batter
HAVING SUM(match_runs) >= 500
ORDER BY winning_contribution_percentage DESC;

