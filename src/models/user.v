module models

// vlib
import arrays
import db.mysql as v_mysql
// local
import data.mysql
import utils
// first party
import coachonko.luuid

// Users are either `admin`, `member`, `developer`, `author`, `contributor`
// They are part of the team that runs a peony website.
pub struct User {
pub:
	id            string
	handle        string
	email         string
	password_hash string @[json: '-']
	role          string
	created_at    string @[json: 'createdAt']
	updated_at    string @[json: 'updatedAt']
	deleted_at    string @[json: 'deletedAt'; omitempty]
	first_name    string @[json: 'firstName'; omitempty]
	last_name     string @[json: 'lastName'; omitempty]
	metadata      string @[raw]
}

pub struct UserWriteable {
pub mut:
	handle        string
	email         string
	password_hash string
	role          string
	first_name    string
	last_name     string
	metadata      string
}

// create_user creates a peony user in the database.
// id, email, password_hash and handle are required.
pub fn (uw UserWriteable) create(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	mut columns := '
	id,
	email,
	password_hash,
	handle'

	mut qm := 'UUID_TO_BIN(?), ?, ?, ?'

	mut vars := []mysql.Param{}
	vars = arrays.concat(vars, id, uw.email, uw.password_hash, uw.handle)

	// TODO error if id, email, password or handle are missing

	if uw.role != '' {
		if uw.role != 'admin' && uw.role != 'member' && uw.role != 'developer'
			&& uw.role != 'author' && uw.role != 'contributor' {
			return error('user.role must be either "admin", "member", "developer", "author" or "contributor"')
		}
		columns += ', role'
		vars = arrays.concat(vars, uw.role)
		qm += ', ?'
	}
	if uw.first_name != '' {
		columns += ', first_name'
		vars = arrays.concat(vars, uw.first_name)
		qm += ', ?'
	}
	if uw.last_name != '' {
		columns += ', last_name'
		vars = arrays.concat(vars, uw.last_name)
		qm += ', ?'
	}
	if uw.metadata != '' {
		columns += ', metadata'
		vars = arrays.concat(vars, uw.metadata)
		qm += ', ?'
	}

	query := 'INSERT INTO user (${columns}) VALUES (${qm})'
	mysql.prep_n_exec(mut mysql_conn, query, ...vars)!
}

pub fn (user UserWriteable) update(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	if user.handle == '' {
		return utils.new_peony_error(400, 'handle is required')
	}

	if user.email == '' {
		return utils.new_peony_error(400, 'email is required')
	}

	if user.role != '' && user.role !in allowed_role {
		return utils.new_peony_error(400, 'role invalid')
	}

	mut columns := '
	updated_at = NOW(),
	handle = ?,
	first_name = ?,
	last_name = ?,
	metadata = ?'

	mut vars := []mysql.Param{}
	vars = arrays.concat(vars, mysql.Param(user.handle), mysql.Param(user.first_name),
		mysql.Param(user.last_name), mysql.Param(user.metadata))

	if user.role != '' {
		columns += ', role = ?'
		vars = arrays.concat(vars, mysql.Param(user.role))
	}

	query := '
	UPDATE user
	SET ${columns}
	WHERE id = UUID_TO_BIN(?)
	'
	vars = arrays.concat(vars, mysql.Param(id))
	mysql.prep_n_exec(mut mysql_conn, query, ...vars)!
}

fn user_retrieve(mut mysql_conn v_mysql.DB, column string, var string) !User {
	mut qm := '?'
	if column == 'id' {
		qm = 'UUID_TO_BIN(?)'
	}

	query := '
	SELECT
		BIN_TO_UUID(id),
		handle,
		email,
		role,
		created_at,
		updated_at,
		deleted_at,
		first_name,
		last_name,
		metadata
	FROM user
	WHERE ${column} = ${qm}'

	res := mysql.prep_n_exec(mut mysql_conn, query, var)!

	rows := res.rows()
	if rows.len == 0 {
		return error('No user exists with the given ${column}')
	}

	vals := rows[0].vals

	user := User{
		id: vals[0]
		handle: vals[1]
		email: vals[2]
		role: vals[3]
		created_at: vals[4]
		updated_at: vals[5]
		deleted_at: vals[6]
		first_name: vals[7]
		last_name: vals[8]
		metadata: vals[9]
	}

	// TODO add to cache
	return user
}

// user_retrieve_by_id returns the data of a peony user identified by the provided id.
pub fn user_retrieve_by_id(mut mysql_conn v_mysql.DB, id string) !User {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	return user_retrieve(mut mysql_conn, 'id', id)
}

pub fn user_retrieve_by_email(mut mysql_conn v_mysql.DB, email string) !User {
	return user_retrieve(mut mysql_conn, 'email', email)
}

pub fn user_password_hash_by_email(mut mysql_conn v_mysql.DB, email string) !string {
	query := 'SELECT password_hash FROM user WHERE email = ?'
	res := mysql.prep_n_exec(mut mysql_conn, query, email)!
	rows := res.rows()
	if rows.len == 0 {
		return error('No email')
	}
	return rows[0].vals[0]
}

pub fn user_delete_by_id(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	query := '
	UPDATE user
	SET 
		updated_at = NOW(),
		deleted_at = NOW()
	WHERE id = UUID_TO_BIN(?)'
	mysql.prep_n_exec(mut mysql_conn, query, id)!
}

pub fn user_restore_by_id(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	query := '
	UPDATE user
	SET 
	updated_at = NOW(),
	deleted_at = NULL
	WHERE id = UUID_TO_BIN(?)'
	mysql.prep_n_exec(mut mysql_conn, query, id)!
}

// user_list returns an array of all peony users.
pub fn user_list(mut mysql_conn v_mysql.DB) ![]User {
	query := '
	SELECT
		BIN_TO_UUID(id),
		handle,
		email,
		role,
		created_at,
		updated_at,
		deleted_at,
		first_name,
		last_name,
		metadata
	FROM user'
	res := mysql.prep_n_exec(mut mysql_conn, query)!

	rows := res.rows()
	mut users := []User{}

	for row in rows {
		vals := row.vals
		mut user := User{
			id: vals[0]
			handle: vals[1]
			email: vals[2]
			role: vals[3]
			created_at: vals[4]
			updated_at: vals[5]
			deleted_at: vals[6]
			first_name: vals[7]
			last_name: vals[8]
			metadata: vals[9]
		}
		users = arrays.concat(users, user)
	}
	return users
}

/*
*
* author
* An author is a user that has authored posts.
* For a useer to be an author, his id must exist in the post_authors table.
* Note: an author is not a user with role equal to author.
*
*/

// user_list_authors returns an array of peony users that have posts associated with them.
pub fn user_list_authors(mut mysql_conn v_mysql.DB) ![]User {
	query := '
	SELECT DISTINCT
		BIN_TO_UUID(user.id),
		user.handle,
		user.email,
		user.role,
		user.created_at,
		user.updated_at,
		user.deleted_at,
		user.first_name,
		user.last_name,
		user.metadata
	FROM user
	INNER JOIN post ON user.id = post.published_by'
	res := mysql.prep_n_exec(mut mysql_conn, query)!

	rows := res.rows()
	mut users := []User{}

	for row in rows {
		vals := row.vals
		mut user := User{
			id: vals[0]
			handle: vals[1]
			email: vals[2]
			role: vals[3]
			created_at: vals[4]
			updated_at: vals[5]
			deleted_at: vals[6]
			first_name: vals[7]
			last_name: vals[8]
			metadata: vals[9]
		}
		users = arrays.concat(users, user)
	}
	return users
}

fn user_retrieve_author(mut mysql_conn v_mysql.DB, column string, var string) !User {
	mut qm := '?'
	if column == 'id' {
		qm = 'UUID_TO_BIN(?)'
	}

	query := '
	SELECT
		BIN_TO_UUID(id)
		user.handle,
		user.email,
		user.role,
		user.created_at,
		user.updated_at,
		user.deleted_at,
		user.first_name,
		user.last_name,
		user.metadata
	FROM user
	INNER JOIN post_authors on user.id = post_authors.author_id
	WHERE user.${column} = ${qm}'
	res := mysql.prep_n_exec(mut mysql_conn, query, var)!

	rows := res.rows()

	if rows.len == 0 {
		return utils.new_peony_error(404, 'No author exists with the given ${column}')
	}

	vals := rows[0].vals
	return User{
		id: vals[0]
		handle: vals[1]
		email: vals[2]
		role: vals[3]
		created_at: vals[4]
		updated_at: vals[5]
		deleted_at: vals[6]
		first_name: vals[7]
		last_name: vals[8]
		metadata: vals[9]
	}
}

pub fn user_retrieve_author_by_id(mut mysql_conn v_mysql.DB, id string) !User {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	return user_retrieve_author(mut mysql_conn, 'id', id)
}

pub fn user_retrieve_author_by_handle(mut mysql_conn v_mysql.DB, handle string) !User {
	return user_retrieve_author(mut mysql_conn, 'handle', handle)
}

pub fn authors_retrieve_by_post_id(mut mysql_conn v_mysql.DB, post_id string) ![]User {
	luuid.verify(post_id) or { return utils.new_peony_error(400, 'post_id is not a UUID') }

	// TODO check cache
	query := 'SELECT BIN_TO_UUID(author_id) FROM post_authors WHERE post_id = UUID_TO_BIN(?)'

	res := mysql.prep_n_exec(mut mysql_conn, query, post_id)!

	rows := res.rows()
	mut author_ids := []string{}

	for row in rows {
		vals := row.vals
		author_ids = arrays.concat(author_ids, vals[0])
	}

	mut users := []User{}
	for author_id in author_ids {
		user := user_retrieve_by_id(mut mysql_conn, author_id)!
		users = arrays.concat(users, user)
	}

	// TODO add to cache
	return users
}
