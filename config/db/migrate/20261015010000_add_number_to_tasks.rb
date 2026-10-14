# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:tasks) { add_column :number, Integer }

    run <<~SQL
      UPDATE tasks SET number = ranked.number
      FROM (
        SELECT id, row_number() OVER (PARTITION BY project_id ORDER BY created_at, id) AS number FROM tasks
      ) ranked
      WHERE tasks.id = ranked.id
    SQL

    alter_table :tasks do
      set_column_not_null :number
      add_constraint(:tasks_number_check) { number > 0 }
    end

    run "CREATE UNIQUE INDEX tasks_project_id_number_index ON tasks (project_id, number) NULLS NOT DISTINCT"

    run <<~SQL
      CREATE FUNCTION tasks_next_number() RETURNS trigger
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

      CREATE TRIGGER tasks_next_number BEFORE INSERT ON tasks
        FOR EACH ROW EXECUTE FUNCTION tasks_next_number();

      CREATE TRIGGER tasks_next_number_on_move BEFORE UPDATE OF project_id ON tasks
        FOR EACH ROW WHEN (OLD.project_id IS DISTINCT FROM NEW.project_id) EXECUTE FUNCTION tasks_next_number();
    SQL
  end

  down do
    run "DROP TRIGGER tasks_next_number_on_move ON tasks"
    run "DROP TRIGGER tasks_next_number ON tasks"
    run "DROP FUNCTION tasks_next_number()"
    alter_table(:tasks) { drop_column :number }
  end
end
