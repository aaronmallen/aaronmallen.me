# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :sign_in_outcome, %w[signed_in denied github_failed wrong_account unexpected]

    create_table :sign_ins do
      primary_key :id
      column :outcome, :sign_in_outcome, null: false
      column :address, :text, null: false
      column :user_agent, :text, null: false
      column :browser, :text
      column :os, :text
      column :city, :text
      column :country, :country_code
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :sign_ins_user_agent_length, Sequel.lit("length(user_agent) <= 1024")

      index :created_at
    end
  end

  down do
    drop_table :sign_ins
    drop_enum :sign_in_outcome
  end
end
