# frozen_string_literal: true

ROM::SQL.migration do
  up do
    add_enum_value :photo_owner, "decision_comment"

    create_table :decision_comments do
      primary_key :id
      foreign_key :decision_id, :decisions, null: false, on_delete: :cascade
      column :body, :non_blank_text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index %i[decision_id created_at]
    end
  end

  down do
    drop_table :decision_comments

    run <<~SQL
      DELETE FROM photo_claims WHERE owner::text = 'decision_comment';
      ALTER TYPE photo_owner RENAME TO photo_owner_with_decision_comment;
      CREATE TYPE photo_owner AS ENUM ('post', 'journal_entry', 'task', 'task_comment');
      ALTER TABLE photo_claims ALTER COLUMN owner TYPE photo_owner USING owner::text::photo_owner;
      DROP TYPE photo_owner_with_decision_comment;
    SQL
  end
end
