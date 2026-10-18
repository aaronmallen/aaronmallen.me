# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :agent_sessions do
      primary_key :id
      column :title, :non_blank_text, null: false
      column :agent, :contributor_slug, null: false
      column :model, :contributor_slug, null: false
      column :client, :non_blank_text
      column :repo, :repo_name
      column :branch, :non_blank_text
      column :started_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :last_seen_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :ended_at, :timestamptz

      constraint :agent_sessions_title_length_check, Sequel.lit("char_length(title) <= 200")
      constraint :agent_sessions_client_length_check, Sequel.lit("char_length(client) <= 200")
      constraint :agent_sessions_branch_length_check, Sequel.lit("char_length(branch) <= 255")

      index :started_at
      index :last_seen_at, where: Sequel.lit("ended_at IS NULL"), name: :agent_sessions_open_index
    end

    create_table :agent_session_tasks do
      foreign_key :agent_session_id, :agent_sessions, null: false, on_delete: :cascade
      foreign_key :task_id, :tasks, null: false, on_delete: :cascade

      primary_key %i[agent_session_id task_id]
      index :task_id
    end

    create_table :agent_session_loads do
      foreign_key :agent_session_id, :agent_sessions, null: false, on_delete: :cascade
      foreign_key :memory_file_id, :memory_files, null: false, on_delete: :cascade

      primary_key %i[agent_session_id memory_file_id]
      index :memory_file_id
    end

    %i[memory_events artifact_versions].each do |table|
      alter_table table do
        add_foreign_key :session_id, :agent_sessions, on_delete: :set_null
        add_index :session_id
      end
    end

    run <<~SQL
      CREATE TRIGGER agent_sessions_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON agent_sessions
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    %i[memory_events artifact_versions].each do |table|
      alter_table(table) { drop_foreign_key :session_id }
    end

    drop_table :agent_session_loads
    drop_table :agent_session_tasks
    drop_table :agent_sessions
  end
end
