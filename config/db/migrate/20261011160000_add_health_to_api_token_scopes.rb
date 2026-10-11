# frozen_string_literal: true

ROM::SQL.migration do
  with_health = "cardinality(scopes) > 0 AND scopes <@ '{read,suggest,write,publish,delete,health}'::text[]"
  without = "cardinality(scopes) > 0 AND scopes <@ '{read,suggest,write,publish,delete}'::text[]"

  up do
    alter_table :api_tokens do
      drop_constraint :api_tokens_scopes_check
      add_constraint :api_tokens_scopes_check, Sequel.lit(with_health)
    end
  end

  down do
    run "UPDATE api_tokens SET scopes = array_remove(scopes, 'health')"
    run "DELETE FROM api_tokens WHERE cardinality(scopes) = 0"

    alter_table :api_tokens do
      drop_constraint :api_tokens_scopes_check
      add_constraint :api_tokens_scopes_check, Sequel.lit(without)
    end
  end
end
