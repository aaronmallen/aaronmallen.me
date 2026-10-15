# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :link_check_runs do
      primary_key :id
      column :started_at, :timestamptz, null: false
      column :finished_at, :timestamptz
      column :links_checked, :integer, null: false, default: 0
      column :links_due, :integer, null: false
      column :stopped_early, :boolean, generated_always_as: Sequel.lit(<<~SQL)
        finished_at IS NOT NULL AND links_checked < links_due
      SQL
      index :started_at
    end

    run <<~SQL
      CREATE TRIGGER link_check_runs_notify_admin_change AFTER INSERT OR UPDATE OR DELETE ON link_check_runs
        FOR EACH ROW EXECUTE FUNCTION notify_admin_change();
    SQL
  end

  down do
    drop_table :link_check_runs
  end
end
