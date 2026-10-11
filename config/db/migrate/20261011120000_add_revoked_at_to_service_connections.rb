# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:service_connections) { add_column :revoked_at, :timestamptz }
  end

  down do
    alter_table(:service_connections) { drop_column :revoked_at }
  end
end
