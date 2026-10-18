# frozen_string_literal: true

ROM::SQL.migration do
  scopes = %w[read suggest write publish delete health mail agents]
  defaults = { api_tokens: "{read,suggest,write,publish,delete}", oauth_codes: "{read}", oauth_tokens: "{read}" }
  retype = %w[oauth_scope text].to_h do |type|
    sql = defaults.map do |table, default|
      <<~SQL
        ALTER TABLE #{table} ALTER COLUMN scopes DROP DEFAULT;
        ALTER TABLE #{table} ALTER COLUMN scopes TYPE #{type}[] USING scopes::text[]::#{type}[];
        ALTER TABLE #{table} ALTER COLUMN scopes SET DEFAULT '#{default}'::#{type}[];
      SQL
    end
    [type, sql.join]
  end

  up do
    create_enum :oauth_scope, scopes
    alter_table(:api_tokens) { drop_constraint :api_tokens_scopes_check }
    run retype.fetch("oauth_scope")
    alter_table(:api_tokens) { add_constraint :api_tokens_scopes_check, Sequel.lit("cardinality(scopes) > 0") }
  end

  down do
    alter_table(:api_tokens) { drop_constraint :api_tokens_scopes_check }
    run retype.fetch("text")
    drop_enum :oauth_scope
    known = Sequel.lit("cardinality(scopes) > 0 AND scopes <@ '{#{scopes.join(',')}}'::text[]")
    alter_table(:api_tokens) { add_constraint :api_tokens_scopes_check, known }
  end
end
