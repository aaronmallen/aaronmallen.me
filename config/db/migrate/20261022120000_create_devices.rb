# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :devices do
      column :id, :uuid, primary_key: true, default: Sequel.function(:gen_random_uuid)
      column :browser, :text
      column :os, :text
      column :last_signed_in_at, :timestamptz, null: false

      index :last_signed_in_at
    end

    alter_table :sign_ins do
      add_foreign_key :device_id, :devices, type: :uuid, on_delete: :set_null
      add_index :device_id
    end

    run <<~SQL
      CREATE TRIGGER devices_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON devices
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    alter_table(:sign_ins) { drop_foreign_key :device_id }
    drop_table :devices
  end
end
