# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :service_connections do
      add_column :sync_contacts, :boolean, null: false, default: false
      add_column :saves_contacts, :boolean, null: false, default: false

      add_constraint :service_connections_saves_contacts_check, Sequel.|(Sequel.~(:saves_contacts), :sync_contacts)
      add_index :saves_contacts, unique: true, where: :saves_contacts, name: :service_connections_saves_contacts_index
    end

    create_table :contact_syncs do
      foreign_key :google_connection_id, :service_connections, primary_key: true, on_delete: :cascade
      column :sync_token, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table :contact_syncs

    alter_table :service_connections do
      drop_index :saves_contacts, name: :service_connections_saves_contacts_index
      drop_constraint :service_connections_saves_contacts_check
      drop_column :saves_contacts
      drop_column :sync_contacts
    end
  end
end
