# frozen_string_literal: true

ROM::SQL.migration do
  tables = %i[
    analytics_events analytics_rollup_countries analytics_rollup_page_countries known_devices sightings sign_ins
  ].freeze

  up do
    tables.each { |table| alter_table(table) { add_column :country_name, :text } }
  end

  down do
    tables.each { |table| alter_table(table) { drop_column :country_name } }
  end
end
