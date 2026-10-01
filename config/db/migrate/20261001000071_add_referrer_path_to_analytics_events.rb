# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table(:analytics_events) { add_column :referrer_path, :http_path }
  end
end
