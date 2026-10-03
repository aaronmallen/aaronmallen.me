# frozen_string_literal: true

ROM::SQL.migration do
  up do
    zone = Blog::TimeZone::NAME

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

    create_view :work_session_days, <<~SQL
      SELECT
        work_sessions.task_id AS task_id,
        days.day::date AS worked_on,
        floor(extract(epoch FROM
          least(coalesce(work_sessions.ended_at, now()), (days.day + interval '1 day') AT TIME ZONE '#{zone}')
          - greatest(work_sessions.started_at, days.day AT TIME ZONE '#{zone}')
        ))::integer AS seconds
      FROM work_sessions
      CROSS JOIN LATERAL generate_series(
        (work_sessions.started_at AT TIME ZONE '#{zone}')::date::timestamp,
        (coalesce(work_sessions.ended_at, now()) AT TIME ZONE '#{zone}')::date::timestamp,
        interval '1 day'
      ) AS days(day)
    SQL
  end

  down do
    drop_view :work_session_days
    drop_view :review_tasks
  end
end
