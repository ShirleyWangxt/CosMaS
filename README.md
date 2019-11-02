# CS2102 Project - Course Management System

### Pre-requisites
- npm
- node
- psql

### Getting started
- Create a file named `.env`  under the project root directory and copy the content in the `.env.template` to it.

```
DATABASE_URL=postgres://:@localhost:5432/postgres
SECRET=keyboard cat 
```

- Run `psql postgres` and then type `\i ./sql/set_up.sql` to create the tables.

- Run `npm install` to install the dependencies.

- Run `npm start` and go to `localhost:3000`, you should see 
the home page.

### Contributing
- Remember to run `npm run check` and `npm run fix` (if the previous check fails) before you commit!


*{To be updated}*
- Currently, the following pages should be working:
1. `/signup`
2. `/login`
3. `/logout`
4. `/users`
5. `/users/:id/edit`
6. `/semesters`
7. `/semesters/new`
8. `/semesters/:name/edit`
9. `/modules`
10. `/modules/new`
11. `/modules/:module_code/edit`

