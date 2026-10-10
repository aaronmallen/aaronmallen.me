# frozen_string_literal: true

ROM::SQL.migration do
  scopes = "'{read,suggest,write,publish,delete}'::text[]"

  up do
    alter_table :api_tokens do
      add_column :scopes, "text[]", null: false, default: Sequel.lit(scopes)
      add_column :expires_at, :timestamptz

      add_constraint :api_tokens_scopes_check, Sequel.lit("cardinality(scopes) > 0 AND scopes <@ #{scopes}")
    end
  end

  down do
    alter_table :api_tokens do
      drop_constraint :api_tokens_scopes_check
      drop_column :expires_at
      drop_column :scopes
    end
  end
end
