# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run "CREATE DOMAIN short_code AS text CHECK (VALUE ~ '^[a-z0-9]+(-[a-z0-9]+)*$')"

    create_table :short_codes do
      primary_key :id
      column :code, :short_code, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      unique :code, name: :short_codes_code_key
    end

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

    %i[short_codes shares].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :shares
    drop_table :short_codes
    run "DROP DOMAIN short_code"
  end
end
