-- ============================================================
--  Smart Learning & Course Analytics Platform
--  Window functions, nested queries, full-text search, JSON/XML extraction
--  Run the files in numeric order (01 → 06) in MySQL 8.0+
-- ============================================================

USE smart_learning;

-- 6.1 Advanced DQL Queries (WINDOWS FUNCTIONS)

-- Rank students by final grade within each course section
SELECT 
    e.section_id,
    u.user_id AS student_id,
    u.first_name,
    u.last_name,
    e.final_numeric_grade,
    RANK() OVER (PARTITION BY e.section_id ORDER BY e.final_numeric_grade DESC) AS section_rank
FROM smart_learning.enrollments e
JOIN smart_learning.users u ON u.user_id = e.student_id
WHERE e.final_numeric_grade IS NOT NULL;

-- Calculate quartiles of student grades using NTILE(4)
SELECT 
    e.section_id,
    u.user_id,
    e.final_numeric_grade,
    NTILE(4) OVER (PARTITION BY e.section_id ORDER BY e.final_numeric_grade) AS grade_quartile
FROM enrollments e
JOIN users u ON u.user_id = e.student_id
WHERE e.final_numeric_grade IS NOT NULL;

-- Track student submission timing using LAG(): Helps monitor late behaviour or performance drops.
SELECT
    s.student_id,
    s.assignment_id,
    s.submitted_at,
    LAG(s.submitted_at, 1) OVER (PARTITION BY s.student_id ORDER BY s.submitted_at) AS previous_submission_time
FROM submissions s;

-- Compare assignment scores over time with LEAD()
SELECT
    s.student_id,
    s.assignment_id,
    s.score,
    LEAD(s.score, 1) OVER (PARTITION BY s.student_id ORDER BY s.submitted_at) AS next_score
FROM submissions s;

-- 6.2 Advanced DQL Queries (Nested Queries & JOINs)

-- Students who have submitted more than one assignment

SELECT 
    u.user_id,
    u.first_name,
    u.last_name
FROM users u
JOIN enrollments e ON e.student_id = u.user_id
LEFT JOIN submissions s ON s.student_id = u.user_id
WHERE u.role = 'student'
GROUP BY u.user_id
HAVING COUNT(s.submission_id) > 1;



-- Students with average submission score above their section’s assignment average
SELECT 
    s.student_id,
    u.first_name,
    u.last_name,
    AVG(s.score) AS student_avg,
    sub.section_avg
FROM smart_learning.submissions s
JOIN users u ON u.user_id = s.student_id
JOIN (
        SELECT 
            a.section_id,
            AVG(s2.score) AS section_avg
        FROM smart_learning.submissions s2
        JOIN smart_learning.assignments a ON a.assignment_id = s2.assignment_id
        GROUP BY a.section_id
) sub ON sub.section_id = (
            SELECT a2.section_id 
            FROM smart_learning.assignments a2 
            WHERE a2.assignment_id = s.assignment_id
            LIMIT 1
        )
GROUP BY s.student_id, sub.section_avg
HAVING student_avg > sub.section_avg;


-- 6.3 Full Text Search

-- Ranked search returning only the top 5 most relevant 'politics' related.
SELECT 
    course_id,
    title,
    MATCH(title, description) AGAINST ('politics' IN NATURAL LANGUAGE MODE) AS score
FROM courses
WHERE MATCH(title, description) AGAINST ('politics')
ORDER BY score DESC
LIMIT 5;

-- Search for courses related to “research”
SELECT 
    course_id,
    title,
    MATCH(title, description) AGAINST ('research' IN NATURAL LANGUAGE MODE) AS relevance
	FROM smart_learning.courses
	WHERE MATCH(title, description) AGAINST ('research' IN NATURAL LANGUAGE MODE);


-- 6.4 JSON & XML Extraction Queries

-- Count how many students wrote feedback containing the word “great”
SELECT 
    COUNT(*) AS total_with_great
FROM evaluations
WHERE feedback_xml LIKE '%great%';

-- Extract feedback text from XML
SELECT 
    evaluation_id,
    EXTRACTVALUE(feedback_xml, '//comment') AS comment_text
FROM evaluations
WHERE feedback_xml IS NOT NULL;



-- List all assignments that allow PDF submissions
SELECT 
    assignment_id,
    title,
    JSON_SEARCH(settings_json, 'one', '.pdf') AS pdf_allowed
FROM assignments
WHERE JSON_SEARCH(settings_json, 'one', '.pdf') IS NOT NULL;

-- Extract user preference settings
SELECT 
    u.user_id,
    u.first_name,
    JSON_EXTRACT(up.preferences_json, '$.theme') AS theme,
    JSON_EXTRACT(up.preferences_json, '$.notifications') AS notifications_enabled
FROM user_profiles up
JOIN users u ON u.user_id = up.user_id;
