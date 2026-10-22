# frozen_string_literal: true

ROM::SQL.migration do
  index = :memory_files_scope_path_index
  retype = %w[agent_session_index_lines agent_session_searches memory_files].map do |table|
    "ALTER TABLE #{table} ALTER COLUMN scope TYPE memory_scope USING scope::text::memory_scope;"
  end.join("\n")

  up do
    run <<~SQL
      DELETE FROM memory_files
      USING projects
      WHERE memory_files.scope = 'repo' AND projects.repo = memory_files.repo
        AND EXISTS (
          SELECT 1 FROM memory_files taken
          WHERE taken.scope = 'project' AND taken.project_id = projects.id AND taken.path = memory_files.path
        );

      UPDATE memory_files
      SET scope = 'project', project_id = projects.id, repo = NULL
      FROM projects
      WHERE memory_files.scope = 'repo' AND projects.repo = memory_files.repo;

      DELETE FROM memory_files WHERE scope = 'repo';
      UPDATE agent_session_index_lines SET scope = 'project' WHERE scope = 'repo';
      UPDATE agent_session_searches SET scope = 'project' WHERE scope = 'repo';
    SQL

    alter_table(:memory_files) do
      drop_constraint :memory_files_scope_check
      drop_index nil, name: index
      drop_column :repo
    end

    run <<~SQL
      ALTER TYPE memory_scope RENAME TO memory_scope_with_repo;
      CREATE TYPE memory_scope AS ENUM ('global', 'project', 'task');
      #{retype}
      DROP TYPE memory_scope_with_repo;
    SQL

    alter_table(:memory_files) do
      add_constraint :memory_files_scope_check, Sequel.lit(<<~SQL)
        CASE scope
          WHEN 'global' THEN num_nonnulls(project_id, task_id) = 0
          WHEN 'project' THEN project_id IS NOT NULL AND task_id IS NULL
          WHEN 'task' THEN task_id IS NOT NULL AND project_id IS NULL
          ELSE false
        END
      SQL
      add_index %i[scope project_id task_id path], unique: true, nulls_distinct: false, name: index
    end
  end

  down do
    alter_table(:memory_files) do
      drop_constraint :memory_files_scope_check
      drop_index nil, name: index
      add_column :repo, :repo_name
    end

    run <<~SQL
      ALTER TYPE memory_scope RENAME TO memory_scope_without_repo;
      CREATE TYPE memory_scope AS ENUM ('global', 'repo', 'project', 'task');
      #{retype}
      DROP TYPE memory_scope_without_repo;
    SQL

    alter_table(:memory_files) do
      add_constraint :memory_files_scope_check, Sequel.lit(<<~SQL)
        CASE scope
          WHEN 'global' THEN num_nonnulls(repo, project_id, task_id) = 0
          WHEN 'repo' THEN repo IS NOT NULL AND num_nonnulls(project_id, task_id) = 0
          WHEN 'project' THEN project_id IS NOT NULL AND num_nonnulls(repo, task_id) = 0
          WHEN 'task' THEN task_id IS NOT NULL AND num_nonnulls(repo, project_id) = 0
          ELSE false
        END
      SQL
      add_index %i[scope repo project_id task_id path], unique: true, nulls_distinct: false, name: index
    end
  end
end
