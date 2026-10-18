# frozen_string_literal: true

ROM::SQL.migration do
  shipped = %w[
    click_count download_count history_id last_clicked_at last_used_at updated_at view_count zip_download_count
  ]

  notify = Kernel.lambda do |bookkeeping|
    <<~SQL
      CREATE OR REPLACE FUNCTION notify_admin_change() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
      DECLARE
        bookkeeping text[] := ARRAY[#{bookkeeping.map { "'#{it}'" }.join(', ')}];
      BEGIN
        IF TG_OP <> 'UPDATE' OR to_jsonb(OLD) - bookkeeping IS DISTINCT FROM to_jsonb(NEW) - bookkeeping THEN
          PERFORM pg_notify('admin_changes', TG_TABLE_NAME);
        END IF;
        RETURN NULL;
      END;
      $$;
    SQL
  end

  up { run notify.call(shipped + %w[credentials settings_synced_at sync_token synced_from]) }

  down { run notify.call(shipped) }
end
