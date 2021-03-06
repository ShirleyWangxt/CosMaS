/* Semesters */
/* Semesters cannot overlap */
CREATE OR REPLACE FUNCTION validate_semester() RETURNS TRIGGER AS $$
    BEGIN
    IF TG_OP = 'INSERT' THEN
        IF EXISTS (
            SELECT 1
            FROM semesters
            WHERE start_time <= NEW.end_time
                AND end_time >= NEW.start_time) THEN
            RAISE EXCEPTION 'Semesters cannot have overlapped time intervals';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF EXISTS (
            SELECT 1
            FROM semesters
            WHERE start_time != OLD.start_time
                AND end_time != OLD.end_time
                AND start_time <= NEW.end_time
                AND end_time >= NEW.start_time) THEN
            RAISE EXCEPTION 'Semesters cannot have overlapped time intervals';
        END IF;
    END IF;

    RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_semester ON semesters;
CREATE TRIGGER validate_semester
BEFORE INSERT OR UPDATE ON semesters
FOR EACH ROW EXECUTE PROCEDURE
validate_semester();

/* Course requests */
/* Enrol student when course request is approved */
CREATE OR REPLACE FUNCTION enrol_student()
    RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO course_memberships (role, semester_name, module_code, user_id)
        VALUES ('student', NEW.semester_name, NEW.module_code, NEW.requester_id);
        RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enrol_on_request_approval ON course_requests;
CREATE TRIGGER enrol_on_request_approval
AFTER UPDATE ON course_requests
FOR EACH ROW WHEN (NEW.is_approved = true)
EXECUTE PROCEDURE enrol_student();

/* Cannot request to join past courses */
CREATE OR REPLACE FUNCTION check_request_to_past_courses()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' AND OLD.is_approved = false AND NEW.is_approved = true THEN
        IF LOCALTIMESTAMP(0) > (SELECT end_time FROM semesters WHERE name=NEW.semester_name) THEN
            RAISE EXCEPTION 'Requesting or approving request to join past courses';
        END IF;
    END IF;
    RETURN NEW;
END; $$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reject_requests_to_past_courses ON course_requests;
CREATE TRIGGER reject_requests_to_past_courses
BEFORE INSERT OR UPDATE ON course_requests
FOR EACH ROW EXECUTE PROCEDURE
check_request_to_past_courses();

/* Cannot request to join courses the user is already in */
CREATE OR REPLACE FUNCTION check_eligibility_to_request()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.requester_id=NEW.requester_id AND OLD.semester_name=NEW.semester_name AND OLD.module_code=NEW.module_code THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1 FROM course_requests
        WHERE semester_name=NEW.semester_name
        AND module_code=NEW.module_code
        AND requester_id=NEW.requester_id
    ) THEN
        RAISE EXCEPTION 'Cannot have duplicate requests to the same course';
    END IF;

    IF EXISTS (
        SELECT 1 FROM course_memberships
        WHERE semester_name=NEW.semester_name
        AND module_code=NEW.module_code
        AND user_id=NEW.requester_id
    ) THEN
        RAISE EXCEPTION 'Cannot request to join a course that the user is already in';
    END IF;
    RETURN NEW;
END; $$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reject_illegible_requests ON course_requests;
CREATE TRIGGER reject_illegible_requests
BEFORE INSERT ON course_requests
FOR EACH ROW EXECUTE PROCEDURE
check_eligibility_to_request();

CREATE OR REPLACE FUNCTION validate_group_membership() RETURNS TRIGGER AS $$
  BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM course_memberships
      WHERE semester_name = NEW.semester_name
        AND module_code = NEW.module_code
        AND user_id = NEW.user_id
        AND role::text = NEW.role::text) THEN
      RAISE EXCEPTION 'This user does not have the corresponding role in this course';
    END IF;
  END IF;

  RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_group_membership ON group_memberships;
CREATE TRIGGER validate_group_membership
BEFORE INSERT ON group_memberships
FOR EACH ROW EXECUTE PROCEDURE
validate_group_membership();

/* Threads */
CREATE OR REPLACE FUNCTION validate_thread_author() RETURNS TRIGGER AS $$
    BEGIN
    IF NOT EXISTS ( -- non-admin
        SELECT 1
        FROM users
        WHERE id = NEW.author_id AND is_admin)
        AND NOT EXISTS ( -- non professor or TA in the course
            SELECT 1
            FROM course_memberships
            WHERE semester_name = NEW.semester_name
                AND module_code = NEW.module_code
                AND user_id = NEW.author_id
                AND (role = 'professor' OR role = 'TA')
        ) 
        AND NOT EXISTS ( -- no access to the forum
            SELECT 1
            FROM accesses A NATURAL JOIN group_memberships GM
            WHERE semester_name = NEW.semester_name
            AND module_code = NEW.module_code
            AND forum_title = NEW.forum_title
            AND user_id = NEW.author_id
        ) THEN  
            RAISE EXCEPTION 'Thread author is unauthorised to post in this forum';
    END IF;

    RETURN NEW;
    END; 
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_thread_author ON threads;
CREATE TRIGGER validate_thread_author
BEFORE INSERT OR UPDATE ON threads
FOR EACH ROW EXECUTE PROCEDURE
validate_thread_author();

/* Replies */
CREATE OR REPLACE FUNCTION validate_reply_author() RETURNS TRIGGER AS $$
    BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE id = NEW.author_id AND is_admin
    ) AND NOT EXISTS (
        SELECT 1
        FROM course_memberships
        WHERE semester_name = NEW.semester_name
            AND module_code = NEW.module_code
            AND user_id = NEW.author_id
            AND (role = 'professor' OR role = 'TA')
    ) AND NOT EXISTS (
        SELECT 1
        FROM accesses A NATURAL JOIN group_memberships GM
        WHERE semester_name = NEW.semester_name 
            AND module_code = NEW.module_code
            AND forum_title = NEW.forum_title
            AND user_id = NEW.author_id
        ) THEN  
            RAISE EXCEPTION 'Reply author is unauthorised to post in this forum';
    END IF;

    RETURN NEW;
    END; 
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_reply_author ON replies;
CREATE TRIGGER validate_reply_author
BEFORE INSERT OR UPDATE ON replies
FOR EACH ROW EXECUTE PROCEDURE
validate_reply_author();

CREATE OR REPLACE FUNCTION cannot_update_readonly_fields() RETURNS TRIGGER AS $$
    BEGIN
    IF OLD.author_id IS DISTINCT FROM NEW.author_id THEN
        RAISE EXCEPTION 'Thread creation time cannot be modified';
    END IF;

    IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
        RAISE EXCEPTION 'Thread creation time cannot be modified';
    END IF;

    RETURN NEW;
    END; 
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cannot_update_readonly_fields ON threads;
CREATE TRIGGER cannot_update_readonly_fields
BEFORE UPDATE ON threads
FOR EACH ROW EXECUTE PROCEDURE
cannot_update_readonly_fields();

DROP TRIGGER IF EXISTS cannot_update_readonly_fields ON replies;
CREATE TRIGGER cannot_update_readonly_fields
BEFORE UPDATE ON replies
FOR EACH ROW EXECUTE PROCEDURE
cannot_update_readonly_fields();
