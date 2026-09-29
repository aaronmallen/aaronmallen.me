# frozen_string_literal: true

ROM::SQL.migration do
  rollups = {
    analytics_rollup_referrers: %i[host referrer_host],
    analytics_rollup_countries: %i[country_code country_code],
  }.freeze

  up do
    zone = Blog::TimeZone::NAME

    rollups.each do |table, (column, source)|
      alter_table(table) do
        add_column :visitors, :integer
        add_constraint :"#{table}_visitors_check", Sequel.lit("visitors >= 0 AND visitors <= views")
      end

      run <<~SQL
        UPDATE #{table}
        SET visitors = counted.visitors
        FROM (
          SELECT
            (occurred_at AT TIME ZONE '#{zone}')::date AS day,
            #{source} AS value,
            count(DISTINCT visitor_hash)::integer AS visitors
          FROM analytics_events
          GROUP BY 1, 2
        ) AS counted
        WHERE #{table}.day = counted.day AND #{table}.#{column} IS NOT DISTINCT FROM counted.value
      SQL
    end
  end

  down do
    rollups.each_key do |table|
      alter_table(table) { drop_column :visitors }
    end
  end
end
