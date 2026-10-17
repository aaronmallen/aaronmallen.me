# frozen_string_literal: true

ROM::SQL.migration do
  no_transaction

  up do
    add_enum_value :sync_state_kind, "pull_requests", if_not_exists: true

    floor = from(:pull_requests).max(:updated_at)
    from(:sync_states).insert_conflict.insert(kind: "pull_requests", synced_at: floor) if floor
  end

  down do
    transaction do
      run <<~SQL
        DELETE FROM sync_states WHERE kind::text = 'pull_requests';
        DROP TRIGGER sync_states_delete_notify_admin_change ON sync_states;
        DROP TRIGGER sync_states_insert_notify_admin_change ON sync_states;
        DROP TRIGGER sync_states_update_notify_admin_change ON sync_states;
        ALTER TYPE sync_state_kind RENAME TO sync_state_kind_with_pull_requests;
        CREATE TYPE sync_state_kind AS ENUM ('commits', 'backfill', 'failure');
        ALTER TABLE sync_states ALTER COLUMN kind TYPE sync_state_kind USING kind::text::sync_state_kind;
        DROP TYPE sync_state_kind_with_pull_requests;
        CREATE TRIGGER sync_states_delete_notify_admin_change AFTER DELETE ON sync_states FOR EACH ROW
          WHEN (old.kind = 'failure') EXECUTE FUNCTION notify_admin_change();
        CREATE TRIGGER sync_states_insert_notify_admin_change AFTER INSERT ON sync_states FOR EACH ROW
          WHEN (new.kind = 'failure') EXECUTE FUNCTION notify_admin_change();
        CREATE TRIGGER sync_states_update_notify_admin_change AFTER UPDATE ON sync_states FOR EACH ROW
          WHEN (old.kind = 'failure' OR new.kind = 'failure') EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end
end
