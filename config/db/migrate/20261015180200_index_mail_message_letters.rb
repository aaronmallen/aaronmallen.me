# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE EXTENSION IF NOT EXISTS pg_trgm;
      CREATE INDEX mail_messages_letter_index ON mail_messages USING gin (
        (COALESCE(reply_to, '') || ' ' || COALESCE(body, '') || ' ' || COALESCE(from_name, '')) gin_trgm_ops
      );
    SQL
  end

  down do
    run <<~SQL
      DROP INDEX mail_messages_letter_index;
      DROP EXTENSION pg_trgm;
    SQL
  end
end
