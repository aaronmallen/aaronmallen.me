# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :mail_accounts do
      add_column :shown, TrueClass, null: false, default: true
      add_column :sends, TrueClass, null: false, default: true
    end

    alter_table :mail_threads do
      add_column :important, TrueClass, null: false, default: false
    end

    create_table :mail_settings do
      column :id, :integer, primary_key: true, default: 1
      column :contact_form, :boolean, null: false, default: true
      column :people, :boolean, null: false, default: true
      column :needs_reply, :boolean, null: false, default: true
      column :starred, :boolean, null: false, default: true
      column :important, :boolean, null: false, default: false
      column :skip_notifications, :boolean, null: false, default: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :mail_settings_singleton_check, Sequel.lit("id = 1")
    end

    run <<~SQL
      CREATE TRIGGER mail_settings_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON mail_settings
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :mail_settings

    alter_table :mail_threads do
      drop_column :important
    end

    alter_table :mail_accounts do
      drop_column :sends
      drop_column :shown
    end
  end
end
