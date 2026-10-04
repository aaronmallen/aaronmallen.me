# frozen_string_literal: true

ROM::SQL.migration do
  up do
    zone = Blog::TimeZone::NAME

    drop_view :review_tasks

    create_view :review_tasks, <<~SQL
      SELECT
        tasks.id AS task_id,
        tasks.title::text AS title,
        tasks.status::text AS status,
        (tasks.completed_at AT TIME ZONE '#{zone}')::date AS closed_on,
        tasks.worked_seconds AS worked_seconds
      FROM tasks
    SQL

    create_view :review_carries, <<~SQL
      SELECT
        task_events.id AS event_id,
        task_events.task_id AS task_id,
        tasks.title::text AS title,
        task_events.from_sprint_on AS sprint_date,
        task_events.occurred_at AS carried_at
      FROM task_events
      JOIN tasks ON tasks.id = task_events.task_id
      WHERE task_events.kind = 'moved'
        AND task_events.to_sprint_on > task_events.from_sprint_on
        AND task_events.to_sprint_on <= (task_events.occurred_at AT TIME ZONE '#{zone}')::date
    SQL
  end

  down do
    zone = Blog::TimeZone::NAME

    drop_view :review_carries
    drop_view :review_tasks

    create_view :review_tasks, <<~SQL
      SELECT
        tasks.id AS task_id,
        tasks.title::text AS title,
        tasks.status::text AS status,
        (tasks.completed_at AT TIME ZONE '#{zone}')::date AS closed_on,
        tasks.worked_seconds AS worked_seconds,
        tasks.carried_count AS carried_count,
        sprints.sprint_date AS sprint_date
      FROM tasks
      LEFT JOIN sprints ON sprints.id = tasks.sprint_id
    SQL
  end
end
