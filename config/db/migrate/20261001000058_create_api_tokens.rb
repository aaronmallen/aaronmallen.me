# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :api_tokens do
      primary_key :id
      column :name, :non_blank_text, null: false
      column :token_digest, :text, null: false
      column :last_used_at, :timestamptz
      column :revoked_at, :timestamptz
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :api_tokens_name_length_check, Sequel.lit("char_length(name) <= 100")

      index :token_digest, unique: true
    end
  end

  down do
    drop_table :api_tokens
  end
end
