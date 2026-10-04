# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_view :decision_timeline, <<~SQL
      SELECT
        'comment'::text AS kind,
        decision_comments.id AS source_id,
        decision_comments.decision_id AS decision_id,
        decision_comments.created_at AS occurred_at,
        decision_comments.body::text AS body,
        NULL::integer AS option_id,
        NULL::text AS reason,
        NULL::text AS note
      FROM decision_comments
      UNION ALL
      SELECT
        decision_events.kind::text,
        decision_events.id,
        decision_events.decision_id,
        decision_events.created_at,
        NULL,
        decision_events.option_id,
        decision_events.reason::text,
        decision_events.note::text
      FROM decision_events
    SQL
  end

  down do
    drop_view :decision_timeline
  end
end
