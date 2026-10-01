# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :oauth_tokens do
      add_foreign_key :access_token_id, :oauth_tokens, on_delete: :set_null
      add_index :access_token_id
    end
  end

  down do
    alter_table(:oauth_tokens) { drop_foreign_key :access_token_id }
  end
end
