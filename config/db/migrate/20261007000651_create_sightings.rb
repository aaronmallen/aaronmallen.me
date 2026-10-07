# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :sightings do
      primary_key :id
      foreign_key :api_token_id, :api_tokens, on_delete: :cascade
      foreign_key :oauth_client_id, :oauth_clients, on_delete: :cascade
      column :browser, :text
      column :os, :text
      column :city, :text
      column :country, :country_code
      column :calls, :integer, null: false, default: 1
      column :last_address, :text, null: false
      column :last_user_agent, :text, null: false
      column :first_seen_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :last_seen_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :sightings_credential_check, Sequel.lit("num_nonnulls(api_token_id, oauth_client_id) = 1")
      constraint :sightings_last_user_agent_length, Sequel.lit("length(last_user_agent) <= 1024")

      index %i[api_token_id oauth_client_id browser os city country], unique: true, nulls_distinct: false,
                                                                      name: :sightings_credential_device_place_index
      index :oauth_client_id
    end
  end

  down do
    drop_table :sightings
  end
end
