# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :health_days do
      primary_key :id
      column :day, :date, null: false, unique: true
      column :minutes_asleep, :integer
      column :bed_at, :timestamptz
      column :woke_at, :timestamptz
      column :resting_heart_rate, :integer
      column :hrv, :float
      column :steps, :integer
      column :active_zone_minutes, :integer
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    run <<~SQL
      CREATE TRIGGER health_days_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON health_days
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :health_days
  end
end
