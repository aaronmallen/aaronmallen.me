# frozen_string_literal: true

ROM::SQL.migration do
  defaults = { api_tokens: "{read,suggest,write,publish,delete}", oauth_codes: "{read}", oauth_tokens: "{read}" }

  up do
    add_enum_value :oauth_scope, "contacts"
  end

  down do
    kept = fetch("SELECT unnest(enum_range(NULL::oauth_scope))::text AS scope").map(:scope) - ["contacts"]

    defaults.each_key { run "UPDATE #{it} SET scopes = array_remove(scopes, 'contacts')" }
    run "DELETE FROM api_tokens WHERE cardinality(scopes) = 0"
    run "ALTER TYPE oauth_scope RENAME TO oauth_scope_with_contacts"
    create_enum :oauth_scope, kept
    defaults.each do |table, default|
      run <<~SQL
        ALTER TABLE #{table} ALTER COLUMN scopes DROP DEFAULT;
        ALTER TABLE #{table} ALTER COLUMN scopes TYPE oauth_scope[] USING scopes::text[]::oauth_scope[];
        ALTER TABLE #{table} ALTER COLUMN scopes SET DEFAULT '#{default}'::oauth_scope[];
      SQL
    end
    run "DROP TYPE oauth_scope_with_contacts"
  end
end
