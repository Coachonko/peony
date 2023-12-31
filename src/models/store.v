module models

// vlib
import arrays
import db.mysql as v_mysql
// local
import data.mysql
import utils
// first party
import coachonko.luuid

// TODO when requested with a query, fetch more data:
// location
// default_currency
// currencies
// sales_channels
// sales_channels
// payment_providers
// fulfillment_providers
pub struct Store {
pub:
	id                  string
	created_at          string @[json: 'createdAt']
	updated_at          string @[json: 'updatedAt']
	name                string
	default_locale_code string @[json: 'defaultLocaleCode']
	// default_location Location [json: 'defaultLocation']
	default_currency_code string @[json: 'defaultCurrencyCode'; omitempty]
	// default_currency Currency [json: 'defaultCurrency']
	// currencies []Currency
	// swap_link_template string [json: 'swapLinkTemplate']
	// payment_link_template string [json: 'paymentLinkTemplate']
	invite_link_template string @[json: 'inviteLinkTemplate']
	// default_stock_location StockLocation [json: 'defaultStockLocation']
	// stock_locations []StockLocations [json: 'stockLocations']
	// default_sales_channel SalesChannel [json: 'defaultSalesChannelId']
	// sales_channels []SalesChannel
	// payment_providers
	// fulfillment_providers
	metadata string @[raw]
}

pub struct StoreWriteable {
pub mut:
	name                      string
	default_locale_code       string
	default_currency_code     string
	invite_link_template      string
	default_stock_location_id string
	default_sales_channel_id  string
	metadata                  string
}

pub fn (store StoreWriteable) create(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	query := 'INSERT INTO store (id) VALUES (UUID_TO_BIN(?))'
	mysql.prep_n_exec(mut mysql_conn, query, id)!
}

pub fn (sw StoreWriteable) update(mut mysql_conn v_mysql.DB, id string) ! {
	luuid.verify(id) or { return utils.new_peony_error(400, 'id is not a UUID') }

	if sw.name == '' {
		return utils.new_peony_error(400, 'name is required')
	}

	mut query_columns := '
	updated_at = NOW(),
	name = ?,
	metadata = ?'

	mut vars := []mysql.Param{}
	vars = arrays.concat(vars, sw.name)
	vars = arrays.concat(vars, sw.metadata)

	if sw.default_locale_code != '' {
		query_columns += ', default_locale_code = ?'
		vars = arrays.concat(vars, sw.default_locale_code)
	}

	if sw.default_currency_code != '' {
		query_columns += ', default_currency_code = ?'
		vars = arrays.concat(vars, sw.default_currency_code)
	}

	if sw.invite_link_template != '' {
		query_columns += ', invite_link_template = ?'
		vars = arrays.concat(vars, sw.invite_link_template)
	}

	if sw.default_stock_location_id != '' {
		query_columns += ', default_stock_location_id = ?'
		vars = arrays.concat(vars, sw.default_stock_location_id)
	}

	if sw.default_sales_channel_id != '' {
		query_columns += ', default_sales_channel_id = ?'
		vars = arrays.concat(vars, sw.default_sales_channel_id)
	}

	query := '
	UPDATE store
	SET ${query_columns}
	WHERE id = UUID_TO_BIN(?)'

	vars = arrays.concat(vars, id)

	mysql.prep_n_exec(mut mysql_conn, query, ...vars)!
}

pub fn store_retrieve(mut mysql_conn v_mysql.DB) !Store {
	query := '
	SELECT 
		BIN_TO_UUID(id),
		created_at, 
		updated_at, 
		name, 
		default_locale_code,
		default_currency_code, 
		swap_link_template, 
		invite_link_template,
		default_stock_location_id, 
		default_sales_channel_id, 
		metadata
	FROM store'

	res := mysql.prep_n_exec(mut mysql_conn, query)!

	rows := res.rows()

	if rows.len == 0 {
		return utils.new_peony_error(500, 'Store is missing, this should never happen: database needs to be manually fixed.')
	}

	if rows.len > 1 {
		return utils.new_peony_error(500, 'More than one store exists, this should never happen: database needs to be manually fixed.')
	}

	row := rows[0].vals

	mut store := Store{
		id: row[0]
		created_at: row[1]
		updated_at: row[2]
		name: row[3]
		default_locale_code: row[4]
		default_currency_code: row[5]
		// swap_link_template: row[6]
		invite_link_template: row[7]
		// default_stock_location_id: strconv.atoi(row[8]) or { 0 }
		// default_sales_channel_id: strconv.atoi(row[9]) or { 0 }
		metadata: row[10]
	}

	return store
}
