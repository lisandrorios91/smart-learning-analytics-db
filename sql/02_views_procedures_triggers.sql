-- ============================================================
--  Smart Learning & Course Analytics Platform
--  Views, stored procedures and triggers
--  Run the files in numeric order (01 → 06) in MySQL 8.0+
-- ============================================================

USE smart_learning;


-- VIEW 1 [Student Grade Report]
CREATE VIEW vw_StudentGrades AS
SELECT 
    u.user_id,
    u.first_name,
    u.last_name,
    c.title AS course_title,
    s.semester,
    e.final_numeric_grade,
    e.final_letter_grade
FROM smart_learning.enrollments e
JOIN smart_learning.users u ON e.student_id = u.user_id
JOIN smart_learning.course_sections s ON e.section_id = s.section_id
JOIN smart_learning.courses c ON s.course_id = c.course_id;

-- VIEW 2 [Section Enrollment Statistics]
CREATE VIEW vw_SectionStats AS
SELECT 
    c.title,
    s.section_number,
    s.semester,
    COUNT(e.enrollment_id) AS total_enrolled
FROM smart_learning.course_sections s
JOIN smart_learning.courses c ON s.course_id = c.course_id
LEFT JOIN smart_learning.enrollments e ON s.section_id = e.section_id
GROUP BY s.section_id, c.title, s.section_number, s.semester;


-- STORED PROCEDURE 1 - sp_RegisterStudent
DELIMITER //
CREATE PROCEDURE sp_RegisterStudent(
    IN p_student_id INT,
    IN p_section_id INT
)
BEGIN
    DECLARE already_enrolled INT;
    
    SELECT COUNT(*) INTO already_enrolled
    FROM smart_learning.enrollments
    WHERE student_id = p_student_id AND section_id = p_section_id;

    IF already_enrolled > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Student is already enrolled in this section.';
    ELSE
        INSERT INTO enrollments (student_id, section_id, status, enrollment_date)
        VALUES (p_student_id, p_section_id, 'Active', NOW());
    END IF;
END //
DELIMITER ;


-- STORED PROCEDURE 2 - sp_CalculateCourseGrade	
DELIMITER //
CREATE PROCEDURE sp_CalculateCourseGrade(IN p_enrollment_id INT)
BEGIN
    DECLARE v_total_score DECIMAL(10,2);
    DECLARE v_max_points DECIMAL(10,2);
    DECLARE v_percentage DECIMAL(10,2);

    -- Calculates total earned points and total possible points
    SELECT 
        SUM(s.score) AS total_score,
        SUM(a.max_points) AS total_max
    INTO v_total_score, v_max_points
    FROM submissions s
    JOIN assignments a 
        ON s.assignment_id = a.assignment_id
    JOIN enrollments e 
        ON e.student_id = s.student_id 
       AND e.section_id = a.section_id
    WHERE e.enrollment_id = p_enrollment_id;

    -- Handle NULL or zero cases
    IF v_total_score IS NULL OR v_max_points IS NULL OR v_max_points = 0 THEN
        SET v_percentage = NULL;
    ELSE
        SET v_percentage = LEAST((v_total_score / v_max_points) * 100, 100);
    END IF;

    -- Update numeric/letter grade
    UPDATE enrollments
    SET 
        final_numeric_grade = v_percentage,
        final_letter_grade = CASE
            WHEN v_percentage >= 90 THEN 'A'
            WHEN v_percentage >= 80 THEN 'B'
            WHEN v_percentage >= 70 THEN 'C'
            WHEN v_percentage >= 60 THEN 'D'
            WHEN v_percentage IS NULL THEN NULL
            ELSE 'F'
        END
    WHERE enrollment_id = p_enrollment_id;
END //
DELIMITER ;






-- TRIGGER 1 - Recalculate Grades After Submission
DELIMITER //
CREATE TRIGGER trg_after_submission_update
AFTER INSERT ON submissions
FOR EACH ROW
BEGIN
    DECLARE v_enrollment_id INT;

    SELECT enrollment_id 
    INTO v_enrollment_id
    FROM enrollments
    WHERE student_id = NEW.student_id
      AND section_id = (SELECT section_id 
                        FROM assignments 
                        WHERE assignment_id = NEW.assignment_id);

    CALL sp_CalculateCourseGrade(v_enrollment_id);   
END //
DELIMITER ;

SELECT final_numeric_grade
FROM enrollments
ORDER BY final_numeric_grade DESC
LIMIT 10;



-- TRIGGER 2 - Audit User Deletions
DELIMITER //
CREATE TRIGGER trg_users_after_delete
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, changed_by, row_data)
    VALUES ('users', 'DELETE', CURRENT_USER(), JSON_OBJECT('user_id', OLD.user_id, 'role', OLD.role,'email', OLD.email));
END //
DELIMITER ;
