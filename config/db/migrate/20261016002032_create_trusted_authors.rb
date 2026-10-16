# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :trusted_authors do
      column :author_url, :text, primary_key: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    run <<~SQL
      CREATE TRIGGER trusted_authors_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON trusted_authors
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :trusted_authors
  end
end
