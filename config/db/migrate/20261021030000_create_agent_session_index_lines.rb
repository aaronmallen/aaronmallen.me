# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :agent_session_index_lines do
      primary_key :id
      foreign_key :agent_session_id, :agent_sessions, null: false, on_delete: :cascade
      foreign_key :memory_file_id, :memory_files, on_delete: :set_null
      column :path, :text, null: false
      column :scope, :memory_scope, null: false
      column :description, :non_blank_text, null: false
      column :description_agent, :contributor_slug
      column :description_model, :contributor_slug
      column :fact_count, :integer, null: false

      constraint :agent_session_index_lines_description_author_check, Sequel.lit(
        "num_nonnulls(description_agent, description_model) IN (0, 2)",
      )
      constraint :agent_session_index_lines_fact_count_check, Sequel.lit("fact_count >= 0")

      index :agent_session_id
      index :memory_file_id
    end

    run <<~SQL
      CREATE TRIGGER agent_session_index_lines_notify_admin_change
        AFTER INSERT OR UPDATE OR DELETE ON agent_session_index_lines
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :agent_session_index_lines
  end
end
