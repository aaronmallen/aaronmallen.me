# frozen_string_literal: true

ROM::SQL.migration do
  up do
    create_table :note_links do
      foreign_key :note_id, :notes, null: false, on_delete: :cascade
      column :title, :non_blank_text, null: false

      index [:note_id, Sequel.function(:lower, :title)], unique: true, name: :note_links_title_index
      index Sequel.function(:lower, :title), name: :note_links_target_index
    end

    run <<~SQL
      INSERT INTO note_links (note_id, title)
      SELECT DISTINCT ON (notes.id, lower(btrim(link[1]))) notes.id, btrim(link[1])
      FROM notes, regexp_matches(notes.body, '\\[\\[([^]|\\n]+)(?:\\|[^]\\n]+)?\\]\\]', 'g') AS link
      WHERE btrim(link[1]) <> ''
      ORDER BY notes.id, lower(btrim(link[1]));
    SQL
  end

  down do
    drop_table :note_links
  end
end
