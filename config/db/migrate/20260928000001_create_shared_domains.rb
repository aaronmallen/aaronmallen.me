# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      CREATE DOMAIN non_blank_text AS text CHECK (VALUE ~ '\\S');
      CREATE DOMAIN visitor_hash AS text CHECK (VALUE ~ '^[0-9a-f]{64}$');
    SQL
  end

  down do
    run <<~SQL
      DROP DOMAIN visitor_hash;
      DROP DOMAIN non_blank_text;
    SQL
  end
end
