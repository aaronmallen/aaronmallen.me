# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :task_source_state, "started"
  end

  down do
    run <<~SQL
      UPDATE task_sources SET remote_state = 'open' WHERE remote_state = 'started';
      ALTER TABLE task_sources ALTER COLUMN remote_state DROP DEFAULT;
      ALTER TYPE task_source_state RENAME TO task_source_state_with_started;
      CREATE TYPE task_source_state AS ENUM ('open', 'completed', 'not_planned', 'unassigned', 'moved', 'deleted');
      ALTER TABLE task_sources ALTER COLUMN remote_state TYPE task_source_state USING remote_state::text::task_source_state;
      ALTER TABLE task_sources ALTER COLUMN remote_state SET DEFAULT 'open';
      DROP TYPE task_source_state_with_started;
    SQL
  end
end
