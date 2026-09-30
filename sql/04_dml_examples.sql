-- ============================================================
--  Smart Learning & Course Analytics Platform
--  UPDATE and DELETE examples (JSON, XML, cascades, audit log)
--  Run the files in numeric order (01 → 06) in MySQL 8.0+
-- ============================================================

USE smart_learning;

-- 5.3 UPDATE EXAMPLES 

-- 1) Update JSON user preferences (toggle notifications off)
UPDATE user_profiles
SET preferences_json = JSON_SET(preferences_json, '$.notifications', false)
WHERE user_id = 1;

-- 2) Append a new allowed file type to assignment settings
UPDATE assignments
SET settings_json = JSON_ARRAY_APPEND(settings_json, '$.file_types', '.jpg')
WHERE assignment_id = 1;

-- 3) Modify XML comment using string replacement
UPDATE evaluations
SET feedback_xml = REPLACE(
        feedback_xml,
        '<comment>Great course!</comment>',
        '<comment>Great course! Very engaging.</comment>'
    )
WHERE evaluation_id = 1;


-- 4) Update a student submission score
-- Recalculation of final grade occurs only when sp_CalculateCourseGrade is called
UPDATE submissions
SET score = 92
WHERE submission_id = 1;



-- 5.4 DELETE EXAMPLES

-- 1) Delete a submission 
DELETE FROM submissions
WHERE submission_id = 1;

-- 2) Delete a student user
-- CASCADE removes related enrollments, submissions, attendance, evaluations, profile
-- Audit trigger logs the deleted user.
DELETE FROM users
WHERE user_id = 20;

-- 3) Delete an instructor
-- ON DELETE SET NULL preserves section history
DELETE FROM users
WHERE user_id = 8;
