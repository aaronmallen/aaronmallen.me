# frozen_string_literal: true

ROM::SQL.migration do
  up do
    local_time = "timezone('#{Blog::TimeZone::NAME}', analytics_events.occurred_at)"

    run <<~SQL
      INSERT INTO analytics_rollup_hours (day, hour, visitors)
      SELECT analytics_rollups.day, extract(hour FROM #{local_time})::smallint, count(DISTINCT visitor_hash)
      FROM analytics_events
      JOIN analytics_rollups ON analytics_rollups.day = (#{local_time})::date
      GROUP BY 1, 2
      ON CONFLICT (day, hour) DO NOTHING
    SQL
  end
end
