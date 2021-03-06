const bcrypt = require('bcrypt');
const passport = require('passport');
const db = require('../db');
const sql = require('../sql');
const log = require('../helpers/logging');

exports.new_session = (req, res) => {
  res.render('login');
};

exports.create_session = passport.authenticate('local', {
  successRedirect: '/',
  failureRedirect: '/login',
  failureFlash: true
});

exports.delete_session = (req, res) => {
  req.session.destroy();
  req.logout();
  res.redirect('/');
};

exports.new_user = (req, res) => {
  res.render('signup', { targetUser: null });
};

exports.create_user = (req, res, next) => {
  const { id, name } = req.body;
  const raw_password = req.body.password;
  const salt = bcrypt.genSaltSync(10);
  const password_digest = bcrypt.hashSync(raw_password, salt);

  db.query(sql.users.queries.create_user, [id, name, password_digest], err => {
    if (err) {
      log.error('Failed to create user');
      // TODO: refine error message
      req.flash('error', err.message);
      res.render('signup', { targetUser: { id, name } });
    } else {
      req.login({ id, password: raw_password }, loginError => {
        if (loginError) {
          log.error('Failed to login after creating account', { loginError });
          next(err);
        } else {
          req.flash('success', 'Account successfully created!');
          res.redirect('/');
        }
      });
    }
  });
};
