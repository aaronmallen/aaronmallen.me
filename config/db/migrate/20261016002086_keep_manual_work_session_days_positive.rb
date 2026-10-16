# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  view = <<~SQL
    WITH sessions AS (
      SELECT started_at, coalesce(ended_at, now()) AS ended_at FROM work_sessions
    ),
    marked AS (
      SELECT started_at, ended_at,
        CASE WHEN started_at <= max(ended_at) OVER (
          ORDER BY started_at, ended_at ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) THEN 0 ELSE 1 END AS starts
      FROM sessions
    ),
    numbered AS (
      SELECT started_at, ended_at, sum(starts) OVER (ORDER BY started_at, ended_at ROWS UNBOUNDED PRECEDING) AS span
      FROM marked
    ),
    spans AS (
      SELECT min(started_at) AS started_at, max(ended_at) AS ended_at FROM numbered GROUP BY span
    ),
    closed AS (
      SELECT task_id, sum(floor(extract(epoch FROM ended_at - started_at)))::integer AS seconds,
        max(ended_at) AS ended_at
      FROM work_sessions
      WHERE ended_at IS NOT NULL
      GROUP BY task_id
    )
    SELECT
      days.day::date AS worked_on,
      floor(extract(epoch FROM
        least(spans.ended_at, (days.day + interval '1 day') AT TIME ZONE '#{zone}')
        - greatest(spans.started_at, days.day AT TIME ZONE '#{zone}')
      ))::integer AS seconds
    FROM spans
    CROSS JOIN LATERAL generate_series(
      (spans.started_at AT TIME ZONE '#{zone}')::date::timestamp,
      (spans.ended_at AT TIME ZONE '#{zone}')::date::timestamp,
      interval '1 day'
    ) AS days(day)
    UNION ALL
    SELECT
      (coalesce(tasks.completed_at, closed.ended_at) AT TIME ZONE '#{zone}')::date AS worked_on,
      tasks.worked_seconds - coalesce(closed.seconds, 0) AS seconds
    FROM tasks
    LEFT JOIN closed ON closed.task_id = tasks.id
    WHERE tasks.worked_seconds %<compare>s coalesce(closed.seconds, 0)
      AND coalesce(tasks.completed_at, closed.ended_at) IS NOT NULL
  SQL

  up do
    drop_view :work_session_days
    create_view :work_session_days, format(view, compare: ">")
  end

  down do
    drop_view :work_session_days
    create_view :work_session_days, format(view, compare: "<>")
  end
end
