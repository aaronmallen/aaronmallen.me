# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :task_number_counters do
      primary_key :id
      foreign_key :project_id, :projects, on_delete: :cascade
      column :last_number, Integer, null: false

      constraint(:task_number_counters_last_number_check) { last_number > 0 }

      index :project_id, unique: true, nulls_distinct: false
    end

    run <<~SQL
      INSERT INTO task_number_counters (project_id, last_number)
        SELECT project_id, max(number) FROM tasks GROUP BY project_id;

      CREATE OR REPLACE FUNCTION tasks_next_number() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        PERFORM pg_advisory_xact_lock(hashtext('tasks_next_number'), coalesce(NEW.project_id, 0));

        INSERT INTO task_number_counters (project_id, last_number)
          VALUES (
            NEW.project_id,
            (SELECT coalesce(max(number), 0) + 1 FROM tasks WHERE project_id IS NOT DISTINCT FROM NEW.project_id)
          )
          ON CONFLICT (project_id) DO UPDATE
            SET last_number = greatest(task_number_counters.last_number + 1, EXCLUDED.last_number)
          RETURNING last_number INTO NEW.number;

        RETURN NEW;
      END
      $$;
    SQL
  end

  down do
    run <<~SQL
      CREATE OR REPLACE FUNCTION tasks_next_number() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        PERFORM pg_advisory_xact_lock(hashtext('tasks_next_number'), coalesce(NEW.project_id, 0));

        SELECT coalesce(max(number), 0) + 1 INTO NEW.number
          FROM tasks
          WHERE project_id IS NOT DISTINCT FROM NEW.project_id;

        RETURN NEW;
      END
      $$;
    SQL

    drop_table :task_number_counters
  end
end
