# frozen_string_literal: true

ROM::SQL.migration do
  failure_triggers = {
    "sync_states_insert_notify_admin_change" => ["INSERT", "NEW.kind = 'failure'"],
    "sync_states_update_notify_admin_change" => ["UPDATE", "OLD.kind = 'failure' OR NEW.kind = 'failure'"],
    "sync_states_delete_notify_admin_change" => ["DELETE", "OLD.kind = 'failure'"],
  }

  up do
    run <<~SQL
      CREATE OR REPLACE FUNCTION notify_admin_change() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      DECLARE
        bookkeeping text[] := ARRAY[
          'click_count', 'download_count', 'history_id', 'last_clicked_at', 'last_used_at', 'updated_at',
          'view_count', 'zip_download_count'
        ];
      BEGIN
        IF TG_OP <> 'UPDATE' OR to_jsonb(OLD) - bookkeeping IS DISTINCT FROM to_jsonb(NEW) - bookkeeping THEN
          PERFORM pg_notify('admin_changes', TG_TABLE_NAME);
        END IF;
        RETURN NULL;
      END;
      $$;

      DROP TRIGGER sync_states_notify_admin_change ON sync_states;
    SQL

    failure_triggers.each do |name, (event, condition)|
      run <<~SQL
        CREATE TRIGGER #{name} AFTER #{event} ON sync_states
          FOR EACH ROW WHEN (#{condition}) EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    failure_triggers.each_key { run "DROP TRIGGER #{it} ON sync_states;" }

    run <<~SQL
      CREATE TRIGGER sync_states_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON sync_states
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();

      CREATE OR REPLACE FUNCTION notify_admin_change() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      BEGIN
        IF TG_OP <> 'UPDATE' OR OLD IS DISTINCT FROM NEW THEN
          PERFORM pg_notify('admin_changes', TG_TABLE_NAME);
        END IF;
        RETURN NULL;
      END;
      $$;
    SQL
  end
end
