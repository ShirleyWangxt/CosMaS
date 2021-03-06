const db = require('../db');
const sql = require('../sql');
const log = require('../helpers/logging');
const { canCreateCourse, canDeleteCourse, canShowCourseDetails } = require('../permissions/courses');
const { canIndexMembers } = require('../permissions/course_memberships');
const { canCreateCourseRequest, canShowCourseRequestsOfCourse } = require('../permissions/course_requests');
const { canCreateForum, canUpdateForum, canDeleteForum } = require('../permissions/forums');
const { canCreateGroup, canUpdateGroup, canDeleteGroup } = require('../permissions/groups');
const { coursesPath, courseNewPath, courseEditPath } = require('../routes/helpers/courses');

exports.index = async (req, res, next) => {
  const { semester_name, module_code } = req.query;
  try {
    const permissions = {
      can_create_course: await canCreateCourse(req.user),
      can_delete_course: await canDeleteCourse(req.user)
    };

    if (semester_name) {
      db.query(sql.courses.queries.get_courses_by_semester, [semester_name], (err, data) => {
        if (err) {
          log.error(`Failed to get courses offered in ${semester_name}`);
          next(err);
        } else {
          res.render('courses', { data: data.rows, title: `Courses offered in ${semester_name}`, permissions });
        }
      });
    } else if (module_code) {
      db.query(sql.courses.queries.get_courses_by_module, [module_code], (err, data) => {
        if (err) {
          log.error(`Failed to get courses for ${module_code}`);
          next(err);
        } else {
          res.render('courses', { data: data.rows, title: `Courses for module ${module_code}`, permissions });
        }
      });
    } else {
      db.query(sql.courses.queries.get_courses, (err1, data1) => {
        if (err1) {
          log.error('Failed to get courses');
          next(err1);
        } else {
          db.query(sql.semesters.queries.get_current_semester, (err2, data2) => {
            if (err2) {
              log.error(`Failed to get current semester`);
              next(err2);
            } else {
              const semester = data2.rows[0];
              const [past, future, current] = data1.rows.reduce(
                (result, row) => {
                  if (row.end_time < semester.start_time) {
                    result[0].push(row);
                  } else if (row.start_time > semester.end_time) {
                    result[1].push(row);
                  } else {
                    result[2].push(row);
                  }
                  return result;
                },
                [[], [], []]
              );
              res.render('coursesAll', { past, future, current, title: 'All Courses', permissions });
            }
          });
        }
      });
    }
  } catch (err) {
    next(err);
  }
};

exports.show = async (req, res, next) => {
  const { semester_name, module_code } = req.params;
  try {
    const permissions = {
      can_show_course_details: await canShowCourseDetails(req.user, semester_name, module_code),
      can_create_group: await canCreateGroup(req.user, semester_name, module_code),
      can_update_group: await canUpdateGroup(req.user, semester_name, module_code),
      can_delete_group: await canDeleteGroup(req.user, semester_name, module_code),
      can_create_forum: await canCreateForum(req.user, semester_name, module_code),
      can_update_forum: await canUpdateForum(req.user, semester_name, module_code),
      can_delete_forum: await canDeleteForum(req.user, semester_name, module_code),
      can_index_members: await canIndexMembers(req.user, semester_name, module_code),
      can_request_course: await canCreateCourseRequest(req.user, semester_name, module_code, req.user.id),
      can_show_course_requests: await canShowCourseRequestsOfCourse(req.user, semester_name, module_code)
    };
    const course = await db.query(sql.courses.queries.find_course, [semester_name, module_code]).then(
      data => data.rows[0],
      err => {
        log.error(`Failed to get course ${module_code} offered in ${semester_name}`);
        throw err;
      }
    );
    const groups = await db.query(sql.groups.queries.get_groups_by_course, [semester_name, module_code]).then(
      data => data.rows,
      err => {
        log.error(`Failed to get groups of ${module_code} offered in ${semester_name}`);
        throw err;
      }
    );
    const forums = await db.query(sql.forums.queries.get_forums_by_course, [semester_name, module_code]).then(
      data => data.rows,
      err => {
        log.error(`Failed to get forums of ${module_code} offered in ${semester_name}`);
        throw err;
      }
    );
    res.render('course', { course, groups, forums, permissions });
  } catch (err) {
    next(err);
  }
};

exports.new = (req, res, next) => {
  db.query(sql.semesters.queries.get_semesters, (err1, semesters) => {
    if (err1) {
      log.error('Failed to get semesters');
      next(err1);
    } else {
      db.query(sql.modules.queries.get_modules, (err2, modules) => {
        if (err2) {
          log.error('Failed to get modules');
          next(err2);
        } else {
          res.render('courseNew', { semesters: semesters.rows, modules: modules.rows });
        }
      });
    }
  });
};

exports.create = (req, res) => {
  const { semester_name, module_code, title, description, credits } = req.body;

  db.query(sql.courses.queries.create_course, [semester_name, module_code, title, description, credits], err => {
    if (err) {
      log.error('Failed to create course');
      // TODO: refine error message
      req.flash('error', err.message);
      res.redirect(courseNewPath());
    } else {
      req.flash('success', `Course ${module_code} ${title} successfully created in ${semester_name}!`);
      res.redirect(coursesPath());
    }
  });
};

exports.delete = (req, res) => {
  const { semester_name, module_code } = req.params;
  db.query(sql.courses.queries.delete_course, [semester_name, module_code], err => {
    if (err) {
      log.error('Failed to delete course');
      req.flash('error', err.message);
    } else {
      req.flash('success', `Course ${module_code} successfully deleted from ${semester_name}!`);
    }
    res.redirect(coursesPath());
  });
};

exports.edit = (req, res, next) => {
  const { semester_name, module_code } = req.params;
  db.query(sql.courses.queries.find_course, [semester_name, module_code], (err, data) => {
    if (err) {
      log.error('Failed to find course');
      next(err);
    } else {
      const course = data.rows[0];
      db.query(sql.semesters.queries.get_semesters, (err1, semesters) => {
        if (err1) {
          log.error('Failed to get semesters');
          next(err1);
        } else {
          db.query(sql.modules.queries.get_modules, (err2, modules) => {
            if (err2) {
              log.error('Failed to get modules');
              next(err2);
            } else {
              res.render('courseEdit', {
                course,
                semesters: semesters.rows,
                modules: modules.rows
              });
            }
          });
        }
      });
    }
  });
};

exports.update = (req, res) => {
  const old_semester_name = req.params.semester_name;
  const old_module_code = req.params.module_code;
  const { semester_name, module_code, title, description, credits } = req.body;

  db.query(
    sql.courses.queries.update_course,
    [semester_name, module_code, title, description, credits, old_semester_name, old_module_code],
    err => {
      if (err) {
        log.error('Failed to update course');
        req.flash('error', err.message);
        res.redirect(courseEditPath(old_semester_name, old_module_code));
      } else {
        req.flash('success', `Course successfully updated!`);
        res.redirect(coursesPath());
      }
    }
  );
};
