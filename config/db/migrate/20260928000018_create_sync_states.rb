# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :sync_state_kind, %w[commits backfill failure]
    create_enum :sync_name, %w[analytics_rollup commits country_database projects].sort

    create_table :sync_states do
      primary_key :id
      column :kind, :sync_state_kind, null: false
      column :sync, :sync_name
      column :repo, :text
      column :synced_at, :timestamptz, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :failure_reason, :text
      column :failure_message, :text
      column :failing_since, :timestamptz
      column :failure_count, :integer, null: false, default: 0

      index %i[kind sync repo], unique: true, nulls_distinct: false
    end
  end

  down do
    drop_table :sync_states

    drop_enum :sync_name
    drop_enum :sync_state_kind
  end
end
