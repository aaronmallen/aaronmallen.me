# frozen_string_literal: true

ROM::SQL.migration do
  rollups = {
    analytics_rollup_page_referrers: %i[host hostname referrer_host],
    analytics_rollup_page_countries: %i[country_code country_code country_code],
  }.freeze

  up do
    zone = Blog::TimeZone::NAME

    rollups.each do |table, (key, type, source)|
      create_table table do
        primary_key :id
        foreign_key :day, :analytics_rollups, type: :date, null: false, on_delete: :cascade
        column :path, :http_path, null: false
        column key, type
        column :views, :integer, null: false, default: 0
        column :visitors, :integer, null: false, default: 0
        column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
        column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

        constraint(:"#{table}_counts_check", Sequel.lit("views >= 0 AND visitors >= 0 AND visitors <= views"))

        index [:day, :path, key], unique: true, nulls_distinct: false
      end

      run <<~SQL
        INSERT INTO #{table} (day, path, #{key}, views, visitors)
        SELECT
          (occurred_at AT TIME ZONE '#{zone}')::date AS day,
          path,
          #{source},
          count(id)::integer,
          count(DISTINCT visitor_hash)::integer
        FROM analytics_events
        WHERE (occurred_at AT TIME ZONE '#{zone}')::date IN (SELECT day FROM analytics_rollups)
        GROUP BY 1, 2, 3
      SQL
    end
  end

  down do
    rollups.each_key { drop_table it }
  end
end
