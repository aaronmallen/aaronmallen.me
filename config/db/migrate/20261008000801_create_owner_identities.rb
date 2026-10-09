# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :owner_identities do
      primary_key :id
      column :provider, :non_blank_text, null: false
      column :external_id, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[provider external_id], unique: true
    end
  end

  down do
    drop_table :owner_identities
  end
end
