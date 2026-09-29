# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :task_status, "canceled"
  end

  down do
    run <<~SQL
      ALTER TABLE tasks DROP CONSTRAINT tasks_completed_at_check;
      ALTER TABLE tasks ALTER COLUMN status DROP DEFAULT;
      ALTER TYPE task_status RENAME TO task_status_with_canceled;
      CREATE TYPE task_status AS ENUM ('open', 'in_progress', 'done');
      ALTER TABLE tasks ALTER COLUMN status TYPE task_status USING status::text::task_status;
      ALTER TABLE tasks ALTER COLUMN status SET DEFAULT 'open';
      ALTER TABLE tasks ADD CONSTRAINT tasks_completed_at_check CHECK ((status = 'done') = (completed_at IS NOT NULL));
      DROP TYPE task_status_with_canceled;
    SQL
  end
end
