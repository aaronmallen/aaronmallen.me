# frozen_string_literal: true

ROM::SQL.migration do
  no_transaction

  up do
    add_enum_value :oauth_scope, "notes", if_not_exists: true
  end

  down do
    defaults = { api_tokens: "{read,suggest,write,publish,delete}", oauth_codes: "{read}", oauth_tokens: "{read}" }

    transaction do
      defaults.each_key do |table|
        run <<~SQL
          UPDATE #{table} SET scopes = array_remove(scopes, 'notes');
          ALTER TABLE #{table} ALTER COLUMN scopes DROP DEFAULT;
        SQL
      end
      run <<~SQL
        DELETE FROM api_tokens WHERE cardinality(scopes) = 0;
        ALTER TYPE oauth_scope RENAME TO oauth_scope_with_notes;
        CREATE TYPE oauth_scope AS ENUM ('read', 'suggest', 'write', 'publish', 'delete', 'health', 'mail', 'agents');
      SQL
      defaults.each do |table, default|
        run <<~SQL
          ALTER TABLE #{table} ALTER COLUMN scopes TYPE oauth_scope[] USING scopes::text[]::oauth_scope[];
          ALTER TABLE #{table} ALTER COLUMN scopes SET DEFAULT '#{default}'::oauth_scope[];
        SQL
      end
      run "DROP TYPE oauth_scope_with_notes"
    end
  end
end
