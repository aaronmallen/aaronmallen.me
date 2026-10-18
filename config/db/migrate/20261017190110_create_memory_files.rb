# frozen_string_literal: true

ROM::SQL.migration do
  paired = "(type IS NULL) = (text IS NULL) AND (was_type IS NULL) = (was_text IS NULL)"

  up do
    create_enum :memory_scope, %w[global repo project task]
    create_enum :memory_fact_type, %w[preference convention gotcha context]
    create_enum :memory_event_op, %w[create add edit remove revert scope]

    create_table :memory_files do
      primary_key :id
      column :path, :text, null: false
      column :scope, :memory_scope, null: false
      column :repo, :repo_name
      foreign_key :project_id, :projects, on_delete: :cascade
      foreign_key :task_id, :tasks, on_delete: :cascade
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :memory_files_path_check, Sequel.lit("path ~ '^[\\w./-]+\\.md$'")
      constraint :memory_files_scope_check, Sequel.lit(<<~SQL)
        CASE scope
          WHEN 'global' THEN num_nonnulls(repo, project_id, task_id) = 0
          WHEN 'repo' THEN repo IS NOT NULL AND num_nonnulls(project_id, task_id) = 0
          WHEN 'project' THEN project_id IS NOT NULL AND num_nonnulls(repo, task_id) = 0
          WHEN 'task' THEN task_id IS NOT NULL AND num_nonnulls(repo, project_id) = 0
          ELSE false
        END
      SQL

      index %i[scope repo project_id task_id path], unique: true, nulls_distinct: false,
                                                    name: :memory_files_scope_path_index
      index :project_id
      index :task_id
    end

    create_table :memory_facts do
      primary_key :id
      foreign_key :memory_file_id, :memory_files, null: false, on_delete: :cascade
      column :type, :memory_fact_type, null: false
      column :text, :non_blank_text, null: false
      column :agent, :contributor_slug
      column :model, :contributor_slug
      column :removed_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :memory_facts_text_length_check, Sequel.lit("char_length(text) <= 1000")
      constraint :memory_facts_author_check, Sequel.lit("num_nonnulls(agent, model) IN (0, 2)")

      index :memory_file_id
    end

    create_table :memory_events do
      primary_key :id
      foreign_key :memory_file_id, :memory_files, null: false, on_delete: :cascade
      foreign_key :memory_fact_id, :memory_facts, on_delete: :cascade
      column :op, :memory_event_op, null: false
      column :type, :memory_fact_type
      column :text, :text
      column :was_type, :memory_fact_type
      column :was_text, :text
      foreign_key :reverted_event_id, :memory_events, on_delete: :cascade
      column :agent, :contributor_slug
      column :model, :contributor_slug
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :memory_events_author_check, Sequel.lit("num_nonnulls(agent, model) IN (0, 2)")
      constraint :memory_events_state_check, Sequel.lit(paired)
      constraint :memory_events_op_check, Sequel.lit(<<~SQL)
        CASE op
          WHEN 'create' THEN num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0
          WHEN 'scope' THEN num_nonnulls(memory_fact_id, text, was_text, reverted_event_id) = 0
          WHEN 'add' THEN memory_fact_id IS NOT NULL AND text IS NOT NULL AND num_nonnulls(was_text, reverted_event_id) = 0
          WHEN 'edit' THEN num_nonnulls(memory_fact_id, text, was_text) = 3 AND reverted_event_id IS NULL
          WHEN 'remove' THEN memory_fact_id IS NOT NULL AND was_text IS NOT NULL AND num_nonnulls(text, reverted_event_id) = 0
          WHEN 'revert' THEN num_nonnulls(memory_fact_id, reverted_event_id) = 2 AND num_nonnulls(text, was_text) > 0
          ELSE false
        END
      SQL

      index %i[memory_file_id created_at]
      index :memory_fact_id
    end

    %w[memory_files memory_facts memory_events].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :memory_events
    drop_table :memory_facts
    drop_table :memory_files

    drop_enum :memory_event_op
    drop_enum :memory_fact_type
    drop_enum :memory_scope
  end
end
