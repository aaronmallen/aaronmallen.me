# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :decision_status, %w[open resolved dropped]
    create_enum :decision_event_kind, %w[opened option_added option_edited edited resolved dropped reopened]

    create_table :decisions do
      primary_key :id
      column :title, :non_blank_text, null: false
      column :problem, :non_blank_text, null: false
      column :status, :decision_status, null: false, default: "open"
      column :resolved_option_id, Integer
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :decisions_choice_check, Sequel.lit("(status = 'resolved') = (resolved_option_id IS NOT NULL)")

      index :status
    end

    create_table :decision_options do
      primary_key :id
      foreign_key :decision_id, :decisions, null: false, on_delete: :cascade
      column :title, :non_blank_text, null: false
      column :body, :text, null: false, default: ""
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      unique %i[decision_id id], name: :decision_options_decision_id_id_key
    end

    alter_table(:decisions) do
      add_foreign_key %i[id resolved_option_id], :decision_options,
                      key: %i[decision_id id], name: :decisions_resolved_option_fkey
    end

    create_table :decision_events do
      primary_key :id
      foreign_key :decision_id, :decisions, null: false, on_delete: :cascade
      column :kind, :decision_event_kind, null: false
      column :option_id, Integer
      column :reason, :non_blank_text
      column :note, :non_blank_text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      foreign_key %i[decision_id option_id], :decision_options,
                  key: %i[decision_id id], on_delete: :cascade, name: :decision_events_option_fkey

      constraint :decision_events_note_length_check, Sequel.lit("char_length(note) <= 500")
      constraint :decision_events_kind_check, Sequel.lit(<<~SQL)
        CASE kind
          WHEN 'opened' THEN num_nonnulls(option_id, reason, note) = 0
          WHEN 'option_added' THEN option_id IS NOT NULL AND num_nonnulls(reason, note) = 0
          WHEN 'option_edited' THEN option_id IS NOT NULL AND reason IS NULL
          WHEN 'edited' THEN num_nonnulls(option_id, reason) = 0
          WHEN 'resolved' THEN option_id IS NOT NULL AND reason IS NOT NULL AND note IS NULL
          WHEN 'dropped' THEN option_id IS NULL AND reason IS NOT NULL AND note IS NULL
          WHEN 'reopened' THEN option_id IS NULL AND reason IS NOT NULL AND note IS NULL
          ELSE false
        END
      SQL

      index %i[decision_id created_at]
      index %i[decision_id option_id]
    end
  end

  down do
    drop_table :decision_events
    alter_table(:decisions) { drop_foreign_key %i[id resolved_option_id], name: :decisions_resolved_option_fkey }
    drop_table :decision_options
    drop_table :decisions

    drop_enum :decision_event_kind
    drop_enum :decision_status
  end
end
