# frozen_string_literal: true

ROM::SQL.migration do
  moved = <<~SQL
    WHEN 'moved' THEN
      num_nonnulls(from_list, from_sprint_on) = 1
      AND num_nonnulls(to_list, to_sprint_on) = 1
      AND (from_list, from_sprint_on) IS DISTINCT FROM (to_list, to_sprint_on)
      AND num_nonnulls(tag_name, from_status, to_status) = 0
    WHEN 'status_changed' THEN
      from_status IS NOT NULL
      AND to_status IS NOT NULL
      AND from_status <> to_status
      AND num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, tag_name) = 0
  SQL

  tagged = <<~SQL
    tag_name IS NOT NULL
    AND num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, from_status, to_status) = 0
  SQL

  up do
    add_enum_value :task_event_kind, "recurred"

    alter_table :task_events do
      drop_constraint :task_events_kind_check
      add_constraint :task_events_kind_check, Sequel.lit(<<~SQL)
        CASE kind
          #{moved}
          WHEN 'tagged' THEN #{tagged}
          WHEN 'untagged' THEN #{tagged}
          ELSE num_nonnulls(from_list, to_list, from_sprint_on, to_sprint_on, tag_name, from_status, to_status) = 0
        END
      SQL
    end
  end

  down do
    run <<~SQL
      DO $$
      DECLARE
        carries text := pg_get_viewdef('review_carries');
        timeline text := pg_get_viewdef('task_timeline');
      BEGIN
        DELETE FROM task_events WHERE kind::text = 'recurred';
        DROP VIEW review_carries;
        DROP VIEW task_timeline;
        ALTER TABLE task_events DROP CONSTRAINT task_events_kind_check;
        ALTER TYPE task_event_kind RENAME TO task_event_kind_with_recurred;
        CREATE TYPE task_event_kind AS ENUM ('moved', 'tagged', 'untagged', 'status_changed');
        ALTER TABLE task_events ALTER COLUMN kind TYPE task_event_kind USING kind::text::task_event_kind;
        DROP TYPE task_event_kind_with_recurred;
        EXECUTE 'CREATE VIEW review_carries AS ' || carries;
        EXECUTE 'CREATE VIEW task_timeline AS ' || timeline;
      END
      $$;

      ALTER TABLE task_events ADD CONSTRAINT task_events_kind_check CHECK (
        CASE kind
          #{moved}
          ELSE #{tagged}
        END
      );
    SQL
  end
end
