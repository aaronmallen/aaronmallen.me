# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :calendars do
      primary_key :id
      column :account, :non_blank_text, null: false
      column :google_id, :text, null: false
      column :name, :non_blank_text, null: false
      column :writable, :boolean, null: false, default: false
      column :hidden, :boolean, null: false, default: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      unique %i[account google_id]
    end

    create_table :calendar_events do
      primary_key :id
      foreign_key :calendar_id, :calendars, null: false, on_delete: :cascade
      column :google_id, :text, null: false
      column :title, :text
      column :starts_on, :date, null: false
      column :ends_on, :date, null: false
      column :starts_at, :timestamptz
      column :ends_at, :timestamptz
      column :place, :text
      column :meet_url, :text
      column :attendees, "text[]", null: false, default: Sequel.lit("'{}'")
      column :notes, :text
      column :link, :text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      unique %i[calendar_id google_id]
      index %i[starts_on ends_on]
      constraint(:calendar_events_days_in_order) { ends_on >= starts_on }
    end

    %i[calendars calendar_events].each do |table|
      run <<~SQL
        CREATE TRIGGER #{table}_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON #{table}
          FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
      SQL
    end
  end

  down do
    drop_table :calendar_events
    drop_table :calendars
  end
end
