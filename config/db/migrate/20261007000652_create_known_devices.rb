# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :known_devices do
      primary_key :id
      foreign_key :api_token_id, :api_tokens, on_delete: :cascade
      foreign_key :oauth_client_id, :oauth_clients, on_delete: :cascade
      column :browser, :text
      column :os, :text
      column :city, :text
      column :country, :country_code
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :known_devices_credential_check, Sequel.lit("num_nonnulls(api_token_id, oauth_client_id) <= 1")

      index %i[api_token_id oauth_client_id browser os city country], unique: true, nulls_distinct: false,
                                                                      name: :known_devices_credential_device_place_index
      index :oauth_client_id
    end
  end

  down do
    drop_table :known_devices
  end
end
