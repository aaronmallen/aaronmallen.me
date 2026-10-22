# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :devices do
      add_column :signed_out_at, :timestamptz
    end
  end
end
