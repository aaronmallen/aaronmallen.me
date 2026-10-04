# frozen_string_literal: true

ROM::SQL.migration do
  up do
    zone = Blog::TimeZone::NAME

    create_view :review_decisions, <<~SQL
      SELECT
        decision_events.id AS event_id,
        decision_events.decision_id AS decision_id,
        decisions.title::text AS title,
        decision_events.kind::text AS outcome,
        decision_options.title::text AS chosen,
        decision_events.reason::text AS reason,
        (decision_events.created_at AT TIME ZONE '#{zone}')::date AS closed_on,
        decision_events.created_at AS closed_at
      FROM decision_events
      JOIN decisions ON decisions.id = decision_events.decision_id
      LEFT JOIN decision_options ON decision_options.id = decision_events.option_id
      WHERE decision_events.kind IN ('resolved', 'dropped')
    SQL
  end

  down do
    drop_view :review_decisions
  end
end
