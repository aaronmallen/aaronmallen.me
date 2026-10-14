# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :share_groups do
      primary_key :id
      foreign_key :short_code_id, :short_codes, null: false, unique: true, on_delete: :cascade
      column :view_count, :integer, null: false, default: 0
      column :zip_download_count, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :share_groups_counts_check, Sequel.lit("view_count >= 0 AND zip_download_count >= 0")
    end

    create_table :share_group_files do
      primary_key :id
      foreign_key :share_group_id, :share_groups, null: false, on_delete: :cascade
      column :key, :text, null: false, unique: true
      column :filename, :non_blank_text, null: false
      column :content_type, :text, null: false
      column :byte_size, :bigint, null: false
      column :alt_text, :text
      column :download_count, :integer, null: false, default: 0
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :share_group_files_key_check, Sequel.lit("key ~ '^[0-9a-f]{32}$'")
      constraint :share_group_files_counts_check, Sequel.lit("byte_size >= 0 AND download_count >= 0")

      index :share_group_id
    end

    %i[share_groups share_group_files].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :share_group_files, :share_groups
  end
end
