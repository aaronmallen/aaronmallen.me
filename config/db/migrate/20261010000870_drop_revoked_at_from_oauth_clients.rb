# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:oauth_clients) { drop_column :revoked_at }
  end

  down do
    alter_table(:oauth_clients) { add_column :revoked_at, :timestamptz }
  end
end
