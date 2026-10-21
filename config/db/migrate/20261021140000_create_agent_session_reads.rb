# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :agent_session_reads do
      primary_key :id
      foreign_key :agent_session_id, :agent_sessions, null: false, on_delete: :cascade
      foreign_key :memory_file_id, :memory_files, on_delete: :set_null
      column :read_at, :timestamptz, null: false

      index :agent_session_id
      index :memory_file_id
    end

    run <<~SQL
      CREATE TRIGGER agent_session_reads_notify_admin_change
        AFTER INSERT OR UPDATE OR DELETE ON agent_session_reads
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :agent_session_reads
  end
end
