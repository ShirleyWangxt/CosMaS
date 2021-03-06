const db = require('../db');
const sql = require('../sql');
const { dateToDisplayedForm } = require('../helpers/date');
const log = require('../helpers/logging');
const { semestersPath } = require('../routes/helpers/semesters');

exports.index = (req, res, next) => {
  db.query(sql.semesters.queries.get_semesters, (err, data) => {
    if (err) {
      log.error('Failed to get semesters');
      next(err);
    } else {
      data.rows.forEach(sem => {
        Object.assign(sem, {
          start_time: dateToDisplayedForm(sem.start_time),
          end_time: dateToDisplayedForm(sem.end_time)
        });
      });
      res.render('semesters', { data: data.rows });
    }
  });
};

exports.new = (req, res) => {
  res.render('semesterNew', { semester: null });
};

exports.create = (req, res) => {
  const { name, start_time, end_time } = req.body;
  db.query(sql.semesters.queries.create_semester, [name, start_time, end_time], err => {
    if (err) {
      log.error('Failed to create semester');
      // TODO: refine error message
      req.flash('error', err.message);
      res.render('semesterNew', { semester: { name, start_time, end_time } });
    } else {
      req.flash('success', `Semester ${name} successfully created!`);
      res.redirect(semestersPath());
    }
  });
};

exports.delete = (req, res) => {
  const { name } = req.params;
  db.query(sql.semesters.queries.delete_semester, [name], err => {
    if (err) {
      log.error('Failed to delete semester');
      req.flash('error', err.message);
    } else {
      req.flash('success', `Semester ${name} successfully deleted!`);
    }
    res.redirect(semestersPath());
  });
};

exports.edit = (req, res, next) => {
  const { name } = req.params;
  db.query(sql.semesters.queries.find_semester, [name], (err, data) => {
    if (err) {
      log.error('Failed to find semester');
      next(err);
    } else {
      const semester = {
        name: data.rows[0].name,
        start_time: dateToDisplayedForm(data.rows[0].start_time),
        end_time: dateToDisplayedForm(data.rows[0].end_time)
      };
      res.render('semesterEdit', { semester });
    }
  });
};

exports.update = (req, res) => {
  const old_name = req.params.name;
  const { name, start_time, end_time } = req.body;

  db.query(sql.semesters.queries.update_semester, [name, start_time, end_time, old_name], err => {
    if (err) {
      log.error('Failed to update semester');
      req.flash('error', err.message);
      res.render('semesterEdit', { semester: { name: old_name, start_time, end_time } });
    } else {
      req.flash('success', 'Semester successfully updated!');
      res.redirect(semestersPath());
    }
  });
};
