# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      ALTER TYPE photo_owner RENAME TO photo_owner_without_review_note;
      CREATE TYPE photo_owner AS ENUM ('post', 'journal_entry', 'task', 'task_comment', 'decision_comment', 'review_note');
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_without_review_note;
    SQL

    add_column :review_notes, :body, :non_blank_text

    run <<~SQL
      UPDATE review_notes
      SET body = journal_entries.body,
        created_at = journal_entries.created_at,
        updated_at = journal_entries.updated_at
      FROM journal_entries
      WHERE journal_entries.id = review_notes.journal_entry_id;

      UPDATE photo_claims
      SET owner = 'review_note', owner_id = review_notes.id
      FROM review_notes
      WHERE photo_claims.owner = 'journal_entry' AND photo_claims.owner_id = review_notes.journal_entry_id;
    SQL

    alter_table(:review_notes) do
      set_column_not_null :body
      drop_constraint :review_notes_journal_entry_id_fkey
    end

    run "DELETE FROM journal_entries WHERE id IN (SELECT journal_entry_id FROM review_notes);"

    alter_table(:review_notes) { drop_column :journal_entry_id }
  end

  down do
    zone = Blog::TimeZone::NAME

    add_column :review_notes, :journal_entry_id, Integer

    run <<~SQL
      DO $$
      DECLARE
        note record;
        entry_id integer;
      BEGIN
        FOR note IN SELECT * FROM review_notes ORDER BY id LOOP
          INSERT INTO journal_entries (entry_date, entry_time, body, created_at, updated_at)
          VALUES (
            CASE note.period
              WHEN 'week' THEN note.starts_on + 6
              ELSE (note.starts_on + interval '1 month - 1 day')::date
            END,
            (note.created_at AT TIME ZONE '#{zone}')::time(0),
            note.body,
            note.created_at,
            note.updated_at
          )
          RETURNING id INTO entry_id;

          UPDATE review_notes SET journal_entry_id = entry_id WHERE id = note.id;
        END LOOP;
      END $$;

      INSERT INTO tags (name, color, scope)
      SELECT 'review', 'mk-blue', 'private'
      WHERE EXISTS (SELECT 1 FROM review_notes)
      ON CONFLICT (scope, name) DO NOTHING;

      INSERT INTO journal_entry_tags (journal_entry_id, tag_id, tag_scope)
      SELECT review_notes.journal_entry_id, tags.id, tags.scope
      FROM review_notes
      JOIN tags ON tags.name = 'review' AND tags.scope = 'private';

      UPDATE photo_claims
      SET owner = 'journal_entry', owner_id = review_notes.journal_entry_id
      FROM review_notes
      WHERE photo_claims.owner = 'review_note' AND photo_claims.owner_id = review_notes.id;

      DELETE FROM photo_claims WHERE owner = 'review_note';
      ALTER TYPE photo_owner RENAME TO photo_owner_with_review_note;
      CREATE TYPE photo_owner AS ENUM ('post', 'journal_entry', 'task', 'task_comment', 'decision_comment');
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_with_review_note;
    SQL

    alter_table(:review_notes) do
      set_column_not_null :journal_entry_id
      add_foreign_key [:journal_entry_id], :journal_entries, on_delete: :cascade
      add_unique_constraint [:journal_entry_id]
      drop_column :body
    end
  end
end
