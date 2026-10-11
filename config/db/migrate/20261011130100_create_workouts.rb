# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :workouts do
      primary_key :id
      column :google_id, :text, null: false, unique: true
      column :kind, :text, null: false
      column :started_at, :timestamptz, null: false
      column :minutes, :integer, null: false
      column :distance_meters, :float
      column :average_heart_rate, :integer
      column :zone_minutes, :integer
      column :kcal, :integer
      column :device, :text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :started_at
    end

    run <<~SQL
      CREATE TRIGGER workouts_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON workouts
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :workouts
  end
end
