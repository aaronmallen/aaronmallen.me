# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :message_status, %w[unread read spam]

    run <<~SQL
      CREATE DOMAIN email_address AS text CHECK (VALUE ~ '^[^@\\s]+@[^@\\s.]+(\\.[^@\\s.]+)+$');
    SQL

    create_table :messages do
      primary_key :id
      column :reply_to, :email_address, null: false
      column :subject, :non_blank_text, null: false
      column :body, :non_blank_text, null: false
      column :status, :message_status, null: false, default: "unread"
      column :visitor_hash, :visitor_hash, null: false
      column :received_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :status
      index %i[visitor_hash received_at]
    end
  end

  down do
    drop_table :messages

    run <<~SQL
      DROP DOMAIN email_address;
    SQL

    drop_enum :message_status
  end
end
