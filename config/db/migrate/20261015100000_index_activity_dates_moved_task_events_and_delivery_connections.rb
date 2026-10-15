# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE INDEX pull_requests_ready_on_index
        ON pull_requests (((ready_at AT TIME ZONE '#{Blog::TimeZone::NAME}')::date));
      CREATE INDEX pull_requests_finished_on_index
        ON pull_requests (((COALESCE(merged_at, closed_at) AT TIME ZONE '#{Blog::TimeZone::NAME}')::date));
      CREATE INDEX workouts_started_on_index
        ON workouts (((started_at AT TIME ZONE '#{Blog::TimeZone::NAME}')::date));
      CREATE INDEX task_events_moved_from_sprint_on_index
        ON task_events (from_sprint_on) WHERE kind = 'moved';
    SQL

    alter_table(:social_post_deliveries) { add_index :connection_id }
  end

  down do
    alter_table(:social_post_deliveries) { drop_index :connection_id }

    run <<~SQL
      DROP INDEX task_events_moved_from_sprint_on_index;
      DROP INDEX workouts_started_on_index;
      DROP INDEX pull_requests_finished_on_index;
      DROP INDEX pull_requests_ready_on_index;
    SQL
  end
end
