# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :agent_session_searches do
      primary_key :id
      foreign_key :agent_session_id, :agent_sessions, null: false, on_delete: :cascade
      column :searched_at, :timestamptz, null: false
      column :query, :non_blank_text, null: false
      column :scope, :memory_scope
      column :repo, :repo_name
      column :project_id, :integer
      column :task_id, :integer

      index :agent_session_id
    end

    create_table :agent_session_search_hits do
      primary_key :id
      foreign_key :agent_session_search_id, :agent_session_searches, null: false, on_delete: :cascade
      foreign_key :memory_fact_id, :memory_facts, on_delete: :set_null, deferrable: true
      foreign_key :memory_file_id, :memory_files, on_delete: :set_null
      column :text, :non_blank_text, null: false
      column :path, :text, null: false

      index :agent_session_search_id
      index :memory_fact_id
      index :memory_file_id
    end

    %w[agent_session_searches agent_session_search_hits].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change
          AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :agent_session_search_hits
    drop_table :agent_session_searches
  end
end
