# frozen_string_literal: true

ROM::SQL.migration do
  zone = Blog::TimeZone::NAME
  branch = <<~SQL
    UNION ALL
    SELECT
      'new_device'::text,
      known_devices.id,
      format(
        '%s: %s in %s',
        CASE
          WHEN api_tokens.id IS NOT NULL THEN 'API token ' || api_tokens.name
          WHEN oauth_clients.id IS NOT NULL
            THEN 'MCP client ' || coalesce(nullif(btrim(oauth_clients.client_name), ''), oauth_clients.client_id)
          ELSE 'Sign-in'
        END,
        coalesce(nullif(concat_ws(' on ', known_devices.browser, known_devices.os), ''), 'an unknown device'),
        coalesce(nullif(concat_ws(', ', known_devices.city, known_devices.country), ''), 'an unknown place')
      ),
      (known_devices.created_at AT TIME ZONE '#{zone}')::date,
      NULL
    FROM known_devices
    LEFT JOIN api_tokens ON api_tokens.id = known_devices.api_token_id
    LEFT JOIN oauth_clients ON oauth_clients.id = known_devices.oauth_client_id
    WHERE EXISTS (
      SELECT 1 FROM known_devices earlier
        WHERE earlier.id < known_devices.id
          AND earlier.api_token_id IS NOT DISTINCT FROM known_devices.api_token_id
          AND earlier.oauth_client_id IS NOT DISTINCT FROM known_devices.oauth_client_id
    )
  SQL

  up do
    add_enum_value :attention_kind, "new_device"

    run <<~SQL
      DO $$
      DECLARE
        attention text := rtrim(pg_get_viewdef('attention'), E'; \\n');
      BEGIN
        DROP VIEW attention;
        EXECUTE 'CREATE VIEW attention AS ' || attention || ' ' || $branch$#{branch}$branch$;
      END
      $$;

      CREATE TRIGGER known_devices_drop_attention_snoozes
        AFTER DELETE ON known_devices
        FOR EACH ROW EXECUTE FUNCTION attention_snoozes_drop_record('new_device');
    SQL
  end

  down do
    run <<~SQL
      DROP TRIGGER known_devices_drop_attention_snoozes ON known_devices;

      DO $$
      DECLARE
        attention text := pg_get_viewdef('attention');
        branch text := '\\s+UNION ALL\\s+SELECT\\s+''new_device''.*$';
      BEGIN
        IF attention !~ branch THEN
          RAISE EXCEPTION 'new_device branch not found in the attention view';
        END IF;
        DROP VIEW attention;
        EXECUTE 'CREATE VIEW attention AS ' || regexp_replace(attention, branch, '');
      END
      $$;

      DELETE FROM attention_snoozes WHERE kind::text = 'new_device';
      ALTER TYPE attention_kind RENAME TO attention_kind_with_new_device;
      CREATE TYPE attention_kind AS ENUM ('carried', 'draft', 'someday', 'journal');
      ALTER TABLE attention_snoozes
        DROP CONSTRAINT attention_snoozes_record_check,
        ALTER COLUMN kind TYPE attention_kind USING kind::text::attention_kind,
        ADD CONSTRAINT attention_snoozes_record_check CHECK ((kind = 'journal') = (record_id IS NULL));
      DROP TYPE attention_kind_with_new_device;
    SQL
  end
end
