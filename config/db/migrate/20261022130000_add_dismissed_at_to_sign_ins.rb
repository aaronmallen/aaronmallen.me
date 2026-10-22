# frozen_string_literal: true

ROM::SQL.migration do
  change do
    alter_table :sign_ins do
      add_column :dismissed_at, :timestamptz
    end
  end
end
