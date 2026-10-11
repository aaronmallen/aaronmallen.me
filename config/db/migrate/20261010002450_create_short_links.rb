# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :short_links do
      primary_key :id
      foreign_key :short_code_id, :short_codes, null: false, unique: true, on_delete: :cascade
      column :destination, :text, null: false
      column :title, :text
      column :click_count, :integer, null: false, default: 0
      column :last_clicked_at, :timestamptz
      column :retargeted_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :short_links_destination_check, Sequel.lit("destination ~ '^https?://[^\\s/?#]+([/?#]\\S*)?$'")
      constraint :short_links_click_count_check, Sequel.lit("click_count >= 0")
    end

    run <<~SQL
      CREATE TRIGGER short_links_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON short_links
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :short_links
  end
end
