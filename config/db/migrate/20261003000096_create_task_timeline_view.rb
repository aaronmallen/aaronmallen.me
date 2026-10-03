# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_view :task_timeline, <<~SQL
      SELECT
        'comment'::text AS kind,
        task_comments.id AS source_id,
        task_comments.task_id AS task_id,
        task_comments.created_at AS occurred_at,
        NULL::timestamptz AS ended_at,
        task_comments.body::text AS body,
        task_comments.author AS author,
        task_comments.provider AS provider,
        task_comments.remote_id AS remote_id,
        task_comments.url AS url,
        NULL::task_list AS from_list,
        NULL::task_list AS to_list,
        NULL::date AS from_sprint_on,
        NULL::date AS to_sprint_on,
        NULL::text AS tag_name,
        NULL::task_status AS from_status,
        NULL::task_status AS to_status
      FROM task_comments
      UNION ALL
      SELECT
        'session',
        work_sessions.id,
        work_sessions.task_id,
        work_sessions.started_at,
        work_sessions.ended_at,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      FROM work_sessions
      UNION ALL
      SELECT
        task_events.kind::text,
        task_events.id,
        task_events.task_id,
        task_events.occurred_at,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        task_events.from_list,
        task_events.to_list,
        task_events.from_sprint_on,
        task_events.to_sprint_on,
        task_events.tag_name::text,
        task_events.from_status,
        task_events.to_status
      FROM task_events
    SQL
  end

  down do
    drop_view :task_timeline
  end
end
