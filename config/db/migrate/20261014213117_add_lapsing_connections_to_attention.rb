# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  branch = <<~SQL
    UNION ALL
    SELECT
      'lapsing'::text,
      service_connections.id,
      service_connections.label::text,
      (service_connections.lapses_at AT TIME ZONE '#{zone}')::date,
      NULL::integer, NULL::integer, NULL::text, NULL::text, NULL::integer
    FROM service_connections
    WHERE service_connections.lapses_at IS NOT NULL
  SQL

  up do
    add_column :service_connections, :lapses_at, :timestamptz
    add_enum_value :attention_kind, "lapsing"

    run <<~SQL
      DO $$
      DECLARE
        attention text := rtrim(pg_get_viewdef('attention'), E'; \\n');
      BEGIN
        DROP VIEW attention;
        EXECUTE 'CREATE VIEW attention AS ' || attention || ' ' || $branch$#{branch}$branch$;
      END
      $$;

      CREATE TRIGGER service_connections_drop_attention_snoozes
        AFTER DELETE ON service_connections
        FOR EACH ROW EXECUTE FUNCTION attention_snoozes_drop_record('lapsing');
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER service_connections_drop_attention_snoozes ON service_connections;

      DO $$
      DECLARE
        attention text := pg_get_viewdef('attention');
        branch text := '\\s+UNION ALL\\s+SELECT\\s+''lapsing''.*$';
      BEGIN
        IF attention !~ branch THEN
          RAISE EXCEPTION 'lapsing branch not found in the attention view';
        END IF;
        DROP VIEW attention;
        EXECUTE 'CREATE VIEW attention AS ' || regexp_replace(attention, branch, '');
      END
      $$;

      DELETE FROM attention_snoozes WHERE kind::text = 'lapsing';
      ALTER TYPE attention_kind RENAME TO attention_kind_with_lapsing;
      CREATE TYPE attention_kind AS ENUM ('carried', 'draft', 'someday', 'journal', 'new_device', 'broken_link');
      ALTER TABLE attention_snoozes
        DROP CONSTRAINT attention_snoozes_record_check,
        ALTER COLUMN kind TYPE attention_kind USING kind::text::attention_kind,
        ADD CONSTRAINT attention_snoozes_record_check CHECK ((kind = 'journal') = (record_id IS NULL));
      DROP TYPE attention_kind_with_lapsing;
    SQL

    drop_column :service_connections, :lapses_at
  end
end
