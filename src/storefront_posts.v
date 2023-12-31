module main

// vlib
import vweb
import strconv
// local
import models
import utils

@['/storefront/posts'; get]
fn (mut app App) storefront_posts_get() vweb.Result {
	fn_name := 'storefront_posts_get'

	mut q_include_authors := false
	if 'include_authors' in app.query {
		if app.query['include_authors'] == '' {
			err := utils.new_peony_error(400, 'empty include_authors query')
			return app.send_error(err, fn_name)
		} else {
			if utils.can_parse_bool(app.query['include_authors']) {
				q_include_authors = utils.parse_bool(app.query['include_authors'])
			} else {
				err := utils.new_peony_error(400, 'include_authors query cannot be parsed to a boolean value')
				return app.send_error(err, fn_name)
			}
		}
	}

	mut q_filter_handle := []string{}
	if 'filter_handle' in app.query {
		if app.query['filter_handle'] == '' {
			err := utils.new_peony_error(400, 'empty filter_handle query')
			return app.send_error(err, fn_name)
		} else {
			q_filter_handle = app.query['filter_handle'].split(',')
		}
	}

	mut q_filter_tags := []string{}
	if 'filter_tags' in app.query {
		if app.query['filter_tags'] == '' {
			err := utils.new_peony_error(400, 'empty filter_tag query')
			return app.send_error(err, fn_name)
		} else {
			q_filter_tags = app.query['filter_tags'].split(',')
		}
	}

	params := models.PostListParams{
		include_authors: q_include_authors
		filter_post_type: 'post'
		filter_deleted: true
		filter_handle: q_filter_handle
		filter_tag: q_filter_tags
		limit: strconv.atoi(app.query['limit']) or { 0 }
		offset: strconv.atoi(app.query['offset']) or { 0 }
	}

	posts := models.post_list(mut app.db, params) or { return app.send_error(err, fn_name) }
	return app.json(posts)
}

// TODO maybe ID does not exist
@['/storefront/posts/:id'; get]
fn (mut app App) storefront_post_get_by_id(id string) vweb.Result {
	fn_name := 'storefront_post_get_by_id'

	posts := models.post_retrieve_by_id(mut app.db, id) or { return app.send_error(err, fn_name) }
	return app.json(posts)
}

/*
*
* Page
*
*/

// TODO abstract storefront_posts_get to another function, use same as storefront_posts_get
@['/storefront/pages'; get]
fn (mut app App) storefront_pages_get() vweb.Result {
	fn_name := 'storefront_pages_get'

	params := models.PostListParams{
		filter_post_type: 'page'
		filter_deleted: true
		limit: strconv.atoi(app.query['limit']) or { 0 }
		offset: strconv.atoi(app.query['offset']) or { 0 }
	}

	pages := models.post_list(mut app.db, params) or { return app.send_error(err, fn_name) }
	return app.json(pages)
}
