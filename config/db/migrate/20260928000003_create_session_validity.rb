# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :session_validity do
      column :id, :integer, primary_key: true, default: 1
      column :valid_after, :timestamptz, null: false, default: Time.at(0)
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :session_validity_singleton_check, Sequel.lit("id = 1")
    end
  end

  down do
    drop_table :session_validity
  end
end
