-- ============================================================
--  Smart Learning & Course Analytics Platform
--  Database, 11 tables, constraints and indexes
--  Run the files in numeric order (01 → 06) in MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS smart_learning;
USE smart_learning;

-- 1. DEPARTMENTS
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    office_location VARCHAR(100)
);

-- 2. USERS
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    role ENUM('student','instructor','admin') NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);

-- 3. USER PROFILES (1:1 rElationship)
CREATE TABLE user_profiles (
    user_id INT PRIMARY KEY,
    bio TEXT,
    avatar_url VARCHAR(255),
    preferences_json JSON,
    CHECK (JSON_VALID(preferences_json)),
    CONSTRAINT fk_userprofiles_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE

);

-- 4. COURSES
CREATE TABLE courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    department_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    credits INT NOT NULL CHECK (credits > 0),
    CONSTRAINT fk_courses_department FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 5. COURSE SECTIONS
CREATE TABLE course_sections (
    section_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    instructor_id INT NULL,
    section_number VARCHAR(10) NOT NULL,
    semester VARCHAR(50) NOT NULL,
    schedule VARCHAR(255),
    UNIQUE (course_id, section_number, semester),
    CONSTRAINT fk_sections_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_sections_instructor FOREIGN KEY (instructor_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);


-- 6. ENROLLMENTS (M:N relationship)
CREATE TABLE enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    enrollment_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Active','Dropped','Completed'),
    final_numeric_grade DECIMAL(7,2),
    final_letter_grade CHAR(2),
    UNIQUE (student_id, section_id),
    CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_enrollments_section FOREIGN KEY (section_id) REFERENCES course_sections(section_id) ON DELETE CASCADE ON UPDATE CASCADE

);


-- 7. ASSIGNMENTS
CREATE TABLE assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    section_id INT NOT NULL,
    title VARCHAR(100) NOT NULL,
    due_at DATETIME,
    max_points INT NOT NULL CHECK (max_points > 0),
    settings_json JSON,
    CHECK (JSON_VALID(settings_json)),
    CONSTRAINT fk_assignments_section FOREIGN KEY (section_id) REFERENCES course_sections(section_id) ON DELETE CASCADE ON UPDATE CASCADE

);

-- 8. SUBMISSIONS
CREATE TABLE submissions (
    submission_id INT AUTO_INCREMENT PRIMARY KEY,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    score INT CHECK (score >= 0),
    metadata_json JSON,
    CHECK (JSON_VALID(metadata_json)),
    CONSTRAINT fk_submissions_assignment FOREIGN KEY (assignment_id) REFERENCES assignments(assignment_id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT fk_submissions_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE

);

-- 9. ATTENDANCE RECORDS
CREATE TABLE attendance_records (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    session_date DATE NOT NULL,
    status ENUM('Present','Absent','Late') NOT NULL,
    UNIQUE (student_id, section_id, session_date),
    CONSTRAINT fk_attendance_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_section FOREIGN KEY (section_id) REFERENCES course_sections(section_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. EVALUATIONS
CREATE TABLE evaluations (
    evaluation_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    section_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    feedback_xml TEXT,
    UNIQUE (student_id, section_id), 
    CONSTRAINT fk_evaluations_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_evaluations_section FOREIGN KEY (section_id) REFERENCES course_sections(section_id) ON DELETE CASCADE ON UPDATE CASCADE

);

-- 11. AUDIT LOG (TRIGGER-ONLY WRITE)
CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) NOT NULL,
    row_data JSON NOT NULL
);


-- INDEXING STRATEGY
CREATE FULLTEXT INDEX idx_course_fulltext ON courses(title, description);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_enrollments_student ON enrollments(student_id);
CREATE INDEX idx_enrollments_section ON enrollments(section_id);
CREATE INDEX idx_assignments_section ON assignments(section_id);
CREATE INDEX idx_submissions_student ON submissions(student_id);
CREATE INDEX idx_submissions_assignment ON submissions(assignment_id);
CREATE INDEX idx_attendance_student ON attendance_records(student_id);
CREATE INDEX idx_attendance_section ON attendance_records(section_id);
CREATE INDEX idx_evaluations_student ON evaluations(student_id);
CREATE INDEX idx_evaluations_section ON evaluations(section_id);
