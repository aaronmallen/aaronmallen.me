# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :performance_pages do
      primary_key :id
      column :route, :http_path, null: false
      column :device_class, :device_class, null: false
      column :ttfb, :double, null: false
      column :dom_content_loaded, :double, null: false
      column :load, :double, null: false
      column :lcp, :double
      column :occurred_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:performance_pages_ttfb_check) { ttfb >= 0 }
      constraint(:performance_pages_dom_content_loaded_check) { dom_content_loaded >= ttfb }
      constraint(:performance_pages_load_check) { load >= dom_content_loaded }
      constraint(:performance_pages_lcp_check) { lcp >= 0 }

      index :occurred_at
    end
  end

  down do
    drop_table :performance_pages
  end
end
