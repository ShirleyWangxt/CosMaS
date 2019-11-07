/* Course_Memberships */
CREATE OR REPLACE FUNCTION is_member_in_course(
    users.id%TYPE,
    semesters.name%TYPE,
    modules.module_code%TYPE,
    course_memberships.role%TYPE)
    RETURNS BOOLEAN AS
    $func$
    BEGIN

    PERFORM *
    FROM course_memberships
    WHERE user_id = $1 AND
        semester_name = $2 AND
        module_code = $3 AND
        role= $4;
    RETURN FOUND;

    END
    $func$ LANGUAGE plpgsql;

/* Accesses */
CREATE OR REPLACE FUNCTION update_accesses(
    character varying[],
    semesters.name%TYPE,
    modules.module_code%TYPE,
    forums.title%TYPE)
    RETURNS void AS $$
    BEGIN
        DELETE FROM accesses WHERE semester_name=$2 AND module_code=$3 AND forum_title=$4;
        FOR i in 1 .. COALESCE(array_length($1, 1), 0)
	    LOOP
		    INSERT INTO accesses (group_name, semester_name, module_code, forum_title) VALUES($1[i], $2, $3, $4);
	    END LOOP;
    END
    $$ LANGUAGE plpgsql;

/* TAs for group */
CREATE OR REPLACE FUNCTION update_TAs(
    character varying[],
    semesters.name%TYPE,
    modules.module_code%TYPE,
    groups.name%TYPE)
    RETURNS void AS $$
    BEGIN
        DELETE FROM group_memberships WHERE role = 'TA' AND semester_name=$2 AND module_code=$3 AND group_name=$4;
        FOR i in 1 .. COALESCE(array_length($1, 1), 0)
	    LOOP
		    INSERT INTO group_memberships (role, user_id, semester_name, module_code, group_name) VALUES('TA', $1[i], $2, $3, $4);
	    END LOOP;
    END
    $$ LANGUAGE plpgsql;

/* Students for group */
CREATE OR REPLACE FUNCTION update_students(
    character varying[],
    semesters.name%TYPE,
    modules.module_code%TYPE,
    groups.name%TYPE)
    RETURNS void AS $$
    BEGIN
        FOR i in 1 .. COALESCE(array_length($1, 1), 0)
	    LOOP
		    INSERT INTO group_memberships (role, user_id, semester_name, module_code, group_name) VALUES('student', $1[i], $2, $3, $4);
	    END LOOP;
    END
    $$ LANGUAGE plpgsql;

/* Course Requests */
CREATE OR REPLACE FUNCTION is_allowed_to_request(
    users.id%TYPE,
    semesters.name%TYPE,
    modules.module_code%TYPE)
    RETURNS BOOLEAN AS
    $$ DECLARE count_membership numeric; count_request numeric;
    BEGIN
    SELECT COUNT(user_id)
    INTO count_membership
    FROM course_memberships
    WHERE user_id = $1 AND
        semester_name = $2 AND
        module_code = $3;
    SELECT COUNT(requester_id)
    INTO count_request
    FROM course_requests
    WHERE requester_id = $1 AND
        semester_name = $2 AND
        module_code = $3;
    RETURN count_membership + count_request = 0;

    END
    $$ LANGUAGE plpgsql;
