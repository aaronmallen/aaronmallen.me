# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:oauth_codes) { add_column :redirect_uri_sent, :boolean, null: false, default: true }
  end

  down do
    alter_table(:oauth_codes) { drop_column :redirect_uri_sent }
  end
end
