# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_enum :review_period, %w[week month]

    create_table :review_notes do
      primary_key :id
      column :period, :review_period, null: false
      column :starts_on, :date, null: false
      foreign_key :journal_entry_id, :journal_entries, null: false, on_delete: :cascade, unique: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint :review_notes_starts_on_check, Sequel.lit(<<~SQL)
        CASE period
          WHEN 'week' THEN extract(isodow FROM starts_on) = 1
          WHEN 'month' THEN extract(day FROM starts_on) = 1
        END
      SQL

      index %i[period starts_on], unique: true
    end

    run <<~SQL
      INSERT INTO review_notes (period, starts_on, journal_entry_id)
      SELECT DISTINCT ON (entry_date)
        CASE WHEN extract(isodow FROM entry_date) = 7 THEN 'week' ELSE 'month' END::review_period,
        CASE
          WHEN extract(isodow FROM entry_date) = 7 THEN entry_date - 6
          ELSE date_trunc('month', entry_date)::date
        END,
        journal_entries.id
      FROM journal_entries
      JOIN journal_entry_tags ON journal_entry_tags.journal_entry_id = journal_entries.id
      JOIN tags ON tags.id = journal_entry_tags.tag_id AND tags.scope = journal_entry_tags.tag_scope
      WHERE tags.name = 'review'
        AND (
          extract(isodow FROM entry_date) = 7
          OR entry_date = (date_trunc('month', entry_date) + interval '1 month - 1 day')::date
        )
      ORDER BY entry_date, entry_time DESC, journal_entries.id DESC;
    SQL
  end

  down do
    drop_table :review_notes

    drop_enum :review_period
  end
end
