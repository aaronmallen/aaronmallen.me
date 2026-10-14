# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :task_cadence, %w[days weeks month_day month_end month_weekday yearly]

    create_table :task_series do
      primary_key :id
      foreign_key :task_id, :tasks, null: false, unique: true, on_delete: :cascade
      column :cadence, :task_cadence, null: false
      column :every, :smallint
      column :weekday, :smallint
      column :week, :smallint
      column :day, :smallint
      column :month, :smallint
      column :starts_on, :date
      column :paused, :boolean, null: false, default: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:task_series_every_check) { every > 0 }
      constraint(:task_series_weekday_check) { (weekday >= 0) & (weekday <= 6) }
      constraint(:task_series_week_check, Sequel.lit("week IN (-1, 1, 2, 3, 4)"))
      constraint(:task_series_day_check) { (day >= 1) & (day <= 31) }
      constraint(:task_series_month_check) { (month >= 1) & (month <= 12) }
      constraint :task_series_cadence_check, Sequel.lit(<<~SQL)
        CASE cadence
          WHEN 'days' THEN every IS NOT NULL
          WHEN 'weeks' THEN every IS NOT NULL AND weekday IS NOT NULL AND starts_on IS NOT NULL
          WHEN 'month_day' THEN day IS NOT NULL
          WHEN 'month_weekday' THEN week IS NOT NULL AND weekday IS NOT NULL
          WHEN 'yearly' THEN month IS NOT NULL AND day IS NOT NULL
          ELSE true
        END
      SQL
    end

    run <<~SQL
      CREATE TRIGGER task_series_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON task_series
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :task_series
    drop_enum :task_cadence
  end
end
