# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :share_group_files do
      add_foreign_key :short_code_id, :short_codes, unique: true, on_delete: :cascade
      set_column_allow_null :share_group_id
      add_constraint :share_group_files_owner_check, Sequel.lit("num_nonnulls(short_code_id, share_group_id) = 1")
    end

    run <<~SQL
      INSERT INTO share_group_files
        (short_code_id, key, filename, content_type, byte_size, alt_text, download_count, created_at, updated_at)
      SELECT short_code_id, key, filename, content_type, byte_size, alt_text, download_count, created_at, updated_at
        FROM shares ORDER BY id
    SQL

    drop_table :shares
  end

  down do
    create_table :shares do
      primary_key :id
      foreign_key :short_code_id, :short_codes, null: false, unique: true, on_delete: :cascade
      column :key, :text, null: false, unique: true
      column :filename, :non_blank_text, null: false
      column :content_type, :text, null: false
      column :byte_size, :bigint, null: false
      column :alt_text, :text
      column :download_count, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :shares_key_check, Sequel.lit("key ~ '^[0-9a-f]{32}$'")
      constraint :shares_counts_check, Sequel.lit("byte_size >= 0 AND download_count >= 0")
    end

    run <<~SQL
      CREATE TRIGGER shares_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON shares
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();

      INSERT INTO shares
        (short_code_id, key, filename, content_type, byte_size, alt_text, download_count, created_at, updated_at)
      SELECT short_code_id, key, filename, content_type, byte_size, alt_text, download_count, created_at, updated_at
        FROM share_group_files WHERE short_code_id IS NOT NULL ORDER BY id;

      DELETE FROM share_group_files WHERE short_code_id IS NOT NULL;
    SQL

    alter_table :share_group_files do
      drop_constraint :share_group_files_owner_check
      drop_foreign_key :short_code_id
      set_column_not_null :share_group_id
    end
  end
end
