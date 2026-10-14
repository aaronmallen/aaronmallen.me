# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :tasks do
      add_foreign_key :project_id, :projects, on_delete: :set_null
      add_index :project_id
    end

    run <<~SQL
      UPDATE tasks SET project_id = kept.project_id
      FROM (
        SELECT DISTINCT ON (links.left_id) links.left_id AS task_id, links.right_id AS project_id
        FROM record_links links
        JOIN projects ON projects.id = links.right_id
        LEFT JOIN task_sources sources ON sources.task_id = links.left_id AND sources.provider = 'github'
        WHERE links.left_kind = 'task' AND links.right_kind = 'project'
        ORDER BY links.left_id,
          projects.repo IS NOT NULL
            AND projects.repo = lower(substring(sources.url FROM '^https://github\\.com/([^/]+/[^/]+)/issues/[0-9]+$'))
            DESC,
          links.created_at, links.id
      ) kept
      WHERE tasks.id = kept.task_id
    SQL

    from(:record_links).where(left_kind: "task", right_kind: "project").delete

    task_project = Sequel.lit("NOT (left_kind = 'task'::record_kind AND right_kind = 'project'::record_kind)")
    alter_table(:record_links) { add_constraint :record_links_task_project_check, task_project }

    run <<~SQL
      DELETE FROM task_rule_projects held
      USING task_rule_projects kept
      WHERE kept.task_rule_id = held.task_rule_id AND kept.project_id < held.project_id
    SQL

    alter_table :task_rule_projects do
      add_index :task_rule_id, unique: true, name: :task_rule_projects_task_rule_id_key
    end
  end

  down do
    alter_table(:task_rule_projects) { drop_index :task_rule_id, name: :task_rule_projects_task_rule_id_key }
    alter_table(:record_links) { drop_constraint :record_links_task_project_check }

    kinds = %w[task project].map { Sequel.cast(it, :record_kind) }
    linked = from(:tasks).exclude(project_id: nil).select(kinds.first, :id, kinds.last, :project_id)
    from(:record_links).insert(%i[left_kind left_id right_kind right_id], linked)

    alter_table(:tasks) { drop_foreign_key :project_id }
  end
end
