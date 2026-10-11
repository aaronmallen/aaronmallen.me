# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      ALTER TYPE photo_owner RENAME TO photo_owner_without_social_post_part;
      CREATE TYPE photo_owner AS ENUM (
        'post', 'journal_entry', 'task', 'task_comment', 'decision_comment', 'review_note', 'social_post_part'
      );
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_without_social_post_part;
    SQL

    create_table :social_post_photos do
      primary_key :id
      foreign_key :social_post_part_id, :social_post_parts, null: false, on_delete: :cascade
      column :position, :integer, null: false
      foreign_key :photo_key, :photos, key: :key, type: :photo_key, null: false
      column :alt_text, :non_blank_text

      constraint :social_post_photos_position_check, Sequel.lit('"position" BETWEEN 1 AND 4')

      index %i[social_post_part_id position], unique: true
      index :photo_key
    end
  end

  down do
    drop_table :social_post_photos

    run <<~SQL
      DELETE FROM photo_claims WHERE owner = 'social_post_part';
      ALTER TYPE photo_owner RENAME TO photo_owner_with_social_post_part;
      CREATE TYPE photo_owner AS ENUM ('post', 'journal_entry', 'task', 'task_comment', 'decision_comment', 'review_note');
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_with_social_post_part;
    SQL
  end
end
