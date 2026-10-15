# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :search_attempts do
      primary_key :id
      column :visitor_hash, :visitor_hash, null: false
      column :attempted_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :attempted_at
      index %i[visitor_hash attempted_at]
    end
  end
end
