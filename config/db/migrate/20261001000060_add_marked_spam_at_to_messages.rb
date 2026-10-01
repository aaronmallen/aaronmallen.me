# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table(:messages) { add_column :marked_spam_at, :timestamptz }

    from(:messages).where(status: "spam").update(marked_spam_at: :updated_at)

    alter_table :messages do
      add_constraint :messages_marked_spam_at_check, Sequel.lit("(status = 'spam') = (marked_spam_at IS NOT NULL)")
      add_index :marked_spam_at
    end
  end

  down do
    alter_table(:messages) { drop_column :marked_spam_at }
  end
end
