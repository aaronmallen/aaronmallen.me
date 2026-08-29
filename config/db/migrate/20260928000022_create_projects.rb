# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :project_status, %w[active wip paused archived]

    run <<~SQL
      CREATE DOMAIN repo_name AS text CHECK (VALUE ~ '^[a-z0-9][a-z0-9-]*/[a-z0-9._-]+$');
    SQL

    create_table :projects do
      primary_key :id
      column :name, :non_blank_text, null: false
      column :tagline, :text
      column :repo, :repo_name
      column :url, :text
      column :stars, :integer, null: false, default: 0
      column :release, :text
      column :status, :project_status, null: false, default: "active"
      column :featured, :boolean, null: false, default: false
      column :position, :integer, null: false
      column :started_on, :date
      column :archived_on, :date
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :og_image_url, :text

      constraint :projects_archived_on_check, Sequel.lit("archived_on IS NULL OR status = 'archived'")
      constraint :projects_archived_order_check, Sequel.lit("archived_on >= started_on")
      constraint :projects_position_check, Sequel.lit('"position" > 0')
      constraint :projects_stars_check, Sequel.lit("stars >= 0")

      index :archived_on
      index :position, unique: true
      index :repo, unique: true
      index :status
    end
  end

  down do
    drop_table :projects

    run <<~SQL
      DROP DOMAIN repo_name;
    SQL

    drop_enum :project_status
  end
end
