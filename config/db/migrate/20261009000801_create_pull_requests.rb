# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :pull_requests do
      primary_key :id
      column :repo, :text, null: false
      column :number, :integer, null: false
      column :title, :text, null: false
      column :body, :text, null: false, default: ""
      column :url, :text, null: false
      column :ready_at, :timestamptz
      column :merged_at, :timestamptz
      column :closed_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :pull_requests_merged_or_closed_check, Sequel.lit("merged_at IS NULL OR closed_at IS NULL")

      index %i[repo number], unique: true
    end

    run <<~SQL
      CREATE TRIGGER pull_requests_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON pull_requests
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :pull_requests
  end
end
