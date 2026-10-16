# frozen_string_literal: true

ROM::SQL.migration do
  up do
    run <<~SQL
      ALTER TYPE photo_owner RENAME TO photo_owner_without_decision;
      CREATE TYPE photo_owner AS ENUM (
        'post', 'journal_entry', 'task', 'task_comment', 'decision_comment', 'review_note', 'social_post_part',
        'decision', 'decision_option'
      );
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_without_decision;
    SQL
  end

  down do
    run <<~SQL
      DELETE FROM photo_claims WHERE owner IN ('decision', 'decision_option');
      ALTER TYPE photo_owner RENAME TO photo_owner_with_decision;
      CREATE TYPE photo_owner AS ENUM (
        'post', 'journal_entry', 'task', 'task_comment', 'decision_comment', 'review_note', 'social_post_part'
      );
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_with_decision;
    SQL
  end
end
