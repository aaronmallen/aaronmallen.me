# frozen_string_literal: true

ROM::SQL.migration do
  up do
    alter_table :webmentions do
      add_column :spam_reason, :non_blank_text
      add_constraint :webmentions_spam_reason_check, Sequel.lit("status = 'spam' OR spam_reason IS NULL")
    end
  end

  down do
    alter_table(:webmentions) { drop_column :spam_reason }
  end
end
