-- ============================================================
--  Smart Learning & Course Analytics Platform
--  Regression, classification and clustering dataset extraction
--  Run the files in numeric order (01 → 06) in MySQL 8.0+
-- ============================================================

USE smart_learning;

-- 7.1 Regression Dataset — Predicting Final Grades

SELECT
    e.student_id,
    e.section_id,
    
    /* Features */
    AVG(s.score) AS avg_score,
    COUNT(s.submission_id) AS submission_count,
    SUM(CASE WHEN ar.status = 'Present' THEN 1 ELSE 0 END) / NULLIF(COUNT(ar.attendance_id), 0) AS attendance_rate,
    c.credits,
    COUNT(DISTINCT a.assignment_id) AS assignment_count, -- Assignment count in the section

    /* Submission completion rate = submissions made ÷ assignments available */
    COUNT(s.submission_id) / NULLIF(COUNT(DISTINCT a.assignment_id), 0)
        AS submission_completion_rate,

    e.final_numeric_grade AS final_numeric_grade -- target

FROM enrollments e
JOIN smart_learning.course_sections cs ON cs.section_id = e.section_id
JOIN smart_learning.courses c ON c.course_id = cs.course_id
LEFT JOIN smart_learning.assignments a ON a.section_id = e.section_id
LEFT JOIN smart_learning.submissions s ON s.student_id = e.student_id 
    AND s.assignment_id = a.assignment_id
LEFT JOIN smart_learning.attendance_records ar ON ar.student_id = e.student_id
    AND ar.section_id = e.section_id

WHERE e.final_numeric_grade IS NOT NULL

GROUP BY e.student_id, e.section_id, c.credits, e.final_numeric_grade;



-- 7.2 Classification Dataset (Predicting Dropout Risk)
WITH assignment_info AS (
    SELECT 
        section_id,
        assignment_id,
        ROW_NUMBER() OVER (PARTITION BY section_id ORDER BY assignment_id) AS rn,
        COUNT(*) OVER (PARTITION BY section_id) AS total_assignments
    FROM assignments
)
SELECT
    e.student_id,
    e.section_id,
    /* Target variable */
    CASE 
        WHEN e.status = 'Dropped' THEN 1
        WHEN e.final_numeric_grade < 60 THEN 1
        ELSE 0
    END AS dropout_risk,
    /* Features */
    SUM(CASE WHEN ar.status = 'Absent' THEN 1 ELSE 0 END) AS absence_count,
    AVG(s.score) AS avg_score,
    /* Browser from JSON metadata */
    (
        SELECT JSON_UNQUOTE(JSON_EXTRACT(s2.metadata_json, '$.browser'))
        FROM submissions s2
        WHERE s2.student_id = e.student_id
        ORDER BY s2.submission_id DESC
        LIMIT 1
    ) AS primary_browser,

    c.credits AS course_credits,
    /* Early grade = avg score from first 25% assignments */
    AVG(CASE WHEN ai.rn <= ai.total_assignments * 0.25 THEN s.score END) AS early_grade,
    e.final_numeric_grade -- Auxiliary
FROM smart_learning.enrollments e
JOIN smart_learning.course_sections cs ON cs.section_id = e.section_id
JOIN smart_learning.courses c ON c.course_id = cs.course_id
LEFT JOIN smart_learning.attendance_records ar 
    ON ar.student_id = e.student_id AND ar.section_id = e.section_id
LEFT JOIN assignment_info ai 
    ON ai.section_id = e.section_id
LEFT JOIN smart_learning.submissions s 
    ON s.student_id = e.student_id AND s.assignment_id = ai.assignment_id

GROUP BY e.student_id, e.section_id, dropout_risk, course_credits, e.final_numeric_grade;



-- 7.3 Clustering Dataset — Student Segmentation

SELECT
    u.user_id AS student_id,
    AVG(s.score) AS mean_score,
    COUNT(s.submission_id) AS total_submissions,

    /* Attendance behavior */
    SUM(CASE WHEN ar.status = 'Present' THEN 1 ELSE 0 END) AS total_present,
    SUM(CASE WHEN ar.status = 'Absent' THEN 1 ELSE 0 END) AS total_absent,
    SUM(CASE WHEN ar.status = 'Late' THEN 1 ELSE 0 END) AS total_late,

    /* Satisfaction extracted from XML */
    AVG(
        CAST(
            SUBSTRING_INDEX(
                SUBSTRING_INDEX(ev.feedback_xml, '<rating>', -1), 
                '</rating>', 
            1) AS UNSIGNED)
    ) AS avg_rating

FROM smart_learning.users u
JOIN smart_learning.enrollments e ON e.student_id = u.user_id
LEFT JOIN smart_learning.submissions s ON s.student_id = u.user_id
LEFT JOIN smart_learning.attendance_records ar ON ar.student_id = u.user_id
LEFT JOIN smart_learning.evaluations ev 
    ON ev.student_id = u.user_id AND ev.section_id = e.section_id

WHERE u.role = 'student'
GROUP BY u.user_id;
