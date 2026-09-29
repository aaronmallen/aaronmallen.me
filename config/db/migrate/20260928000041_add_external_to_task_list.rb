# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :task_list, "external"
  end

  down do
    run <<~SQL
      UPDATE tasks SET list = 'next' WHERE list = 'external';
      ALTER TYPE task_list RENAME TO task_list_with_external;
      CREATE TYPE task_list AS ENUM ('next', 'someday');
      ALTER TABLE tasks ALTER COLUMN list TYPE task_list USING list::text::task_list;
      DROP TYPE task_list_with_external;
    SQL
  end
end
