# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :tag_color, %w[mk-pink mk-green mk-blue mk-violet mk-sand mk-orange]

    run <<~SQL
      CREATE DOMAIN tag_name AS text CHECK (VALUE ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
    SQL

    create_table :tags do
      primary_key :id
      column :name, :tag_name, null: false, unique: true
      column :color, :tag_color, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table :tags

    run <<~SQL
      DROP DOMAIN tag_name;
    SQL

    drop_enum :tag_color
  end
end
